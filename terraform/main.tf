####################################################################################################
# Variables for stage and size based on the current workspace context
####################################################################################################

locals {
  stage   = "${lookup(var.workspace_to_stage_map, terraform.workspace, "dev")}"
  size    = "${lookup(var.stage_to_size_map, local.stage, "small")}"
}

module "landscape_variables" {
  source  = "./modules/variables"
  stage   = local.stage
  size    = local.size
}

####################################################################################################
# Shared infrastructure (shared services resource group, landscape resource group, monitoring, ...)
####################################################################################################

# this is just queried/imported as its does not belong to this state
data "azurerm_resource_group" "shared_services_rg" {
  name     = "shared-services-rg"
}

resource "azurerm_resource_group" "default_rg" {
  name     = "${var.prefix}-${var.environment}-rg"
  location = var.location

  tags = {
    environment = "${var.environment}"
  }
}

resource "azurerm_log_analytics_workspace" "shared" {
  name                = "${var.prefix}-${var.environment}-log"
  resource_group_name = data.azurerm_resource_group.shared_services_rg.name
  location            = data.azurerm_resource_group.shared_services_rg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    environment = "shared_services"
  }

  depends_on = [ data.azurerm_resource_group.shared_services_rg ]
}

####################################################################################################
# Azure Virtual Networks
####################################################################################################

module "aks_vnet" {
  source              = "./modules/vnet"
  name                = "${var.prefix}-${var.environment}-aks-vnet"
  resource_group_name = azurerm_resource_group.default_rg.name
  location            = azurerm_resource_group.default_rg.location

  address_space = ["192.168.0.0/16"]
  subnets = [
    {
      name : "${var.prefix}-${var.environment}-aks-node-subnet"
      address_prefixes : ["192.168.1.0/24"]
    },
    {
      name : "${var.prefix}-${var.environment}-aks-ingress-subnet"
      address_prefixes : ["192.168.2.0/24"]
    }
  ]

  tags = {
    environment = "${var.environment}"
  }
}

####################################################################################################
# Azure Container Registry (Shared)
###################################################################################################

# is just queried/imported as it does not belong to this state
data "azurerm_container_registry" "shared_acr" {
  name                = "${var.prefix}acr"
  resource_group_name = data.azurerm_resource_group.shared_services_rg.name
  depends_on = [ data.azurerm_resource_group.shared_services_rg ]
}

####################################################################################################
# Azure Kubernetes Service (AKS): Service Cluster
####################################################################################################

module "aks_services" {
  source                           = "./modules/aks"
  resource_group_name              = azurerm_resource_group.default_rg.name
  location                         = azurerm_resource_group.default_rg.location
  kubernetes_version               = "1.22.4"
  orchestrator_version             = "1.22.4"
  prefix                           = "${var.prefix}-${var.environment}-aks-services"
  cluster_name                     = "${var.prefix}-${var.environment}-aks-services"
  dns_prefix                       = "${var.prefix}${var.environment}akssrv"
  network_plugin                   = "kubenet"
  enable_role_based_access_control = true
  rbac_aad_managed                 = true
  rbac_aad_admin_user_names        = []
  rbac_aad_admin_group_object_id   = "${var.aks_admin_group_id}" 

  enable_http_application_routing  = false
  enable_azure_policy              = false
  enable_auto_scaling              = false
  node_resource_group              = "${var.prefix}-${var.environment}-node-rg"
  vnet_subnet_id                   = module.aks_vnet.subnet_ids["${var.prefix}-${var.environment}-aks-node-subnet"]
  os_disk_size_gb                  = 50
  agents_count                     = module.landscape_variables.nodecount # Please set `agents_count` `null` while `enable_auto_scaling` is `true` to avoid possible `agents_count` changes.
  agents_size                      = module.landscape_variables.vmsize
  agents_max_pods                  = 100
  agents_pool_name                 = "exnodepool"
  agents_availability_zones        = []
  agents_type                      = "VirtualMachineScaleSets"

  net_profile_pod_cidr             = "172.40.0.0/16"
  net_profile_dns_service_ip       = "172.41.0.10"
  net_profile_docker_bridge_cidr   = "172.42.0.1/16"
  net_profile_service_cidr         = "172.41.0.0/16"
  net_profile_outbound_type        = "loadBalancer"

  enable_log_analytics_workspace   = true
  log_analytics_workspace_group    = azurerm_log_analytics_workspace.shared.resource_group_name
  log_analytics_workspace_id       = azurerm_log_analytics_workspace.shared.id
  log_analytics_workspace_name     = azurerm_log_analytics_workspace.shared.name

  tags = {
    environment = "${var.environment}"
  }

  depends_on = [module.aks_vnet]
}

# add the role to the identity the kubernetes cluster was assigned
resource "azurerm_role_assignment" "aks_to_acr" {
  scope                = data.azurerm_container_registry.shared_acr.id
  role_definition_name = "AcrPull"
  principal_id         = module.aks_services.kubelet_identity.0.object_id
  depends_on=[data.azurerm_container_registry.shared_acr]
}

####################################################################################################
# Azure Keyvault and Secret
####################################################################################################

#data "azuread_service_principal" "vault" {
#  application_id = var.azure_client_id
#}

 resource "azurerm_key_vault" "vault" {
  name                = "${var.prefix}-${var.environment}"
  location            = azurerm_resource_group.default_rg.location
  resource_group_name = azurerm_resource_group.default_rg.name
  tenant_id           = var.azure_tenant_id

  # enable virtual machines to access this key vault.
  # NB this identity is used in the example /tmp/azure_auth.sh file.
  #    vault is actually using the vault service principal.
  enabled_for_deployment = true
  enabled_for_disk_encryption = true
  enabled_for_template_deployment = true

  sku_name = "standard"

  tags = {
    environment = var.environment
  }

  # access policy for the hashicorp vault service principal.
  access_policy {
    tenant_id = var.azure_tenant_id
    object_id = "2c525706-bdaf-43ce-84da-c1882df60dbf" #data.azuread_service_principal.vault.object_id

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Update",
      "WrapKey",
      "UnwrapKey",
      "Recover",
      "Import",
      "Backup",
      "Restore",
      "Purge",
      "Decrypt",
      "Encrypt",
      "Verify",
      "Sign",
    ]
  }

  # TODO does this really need to be so broad? can it be limited?
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }
}

# TODO the "generated" resource name is not very descriptive; why not use "vault" instead?
# hashicorp vault will use this azurerm_key_vault_key to wrap/encrypt its master key.
resource "azurerm_key_vault_key" "hashicorp_vault_key" {
  name         = "hashicorp-vault-key"
  key_vault_id = azurerm_key_vault.vault.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "wrapKey",
    "unwrapKey",
  ]
}

output "key_vault_name" {
  value = azurerm_key_vault.vault.name
}

output "key_vault_key_name" {
  value = azurerm_key_vault_key.hashicorp_vault_key.name
}
