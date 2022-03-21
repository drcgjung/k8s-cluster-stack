module "resource_group" {
  source = "./modules/01_resource_group"

  environment_name = var.environment_name
}

module "aks" {
  source = "./modules/02_aks"

  aks_cluster_name   = "cx-${var.environment_name}-aks"
  aks_location       = module.resource_group.resource_location
  aks_resource_group = module.resource_group.resource_group_name

  aks_service_principal_client_id     = var.service_principal_client_id
  aks_service_principal_client_secret = var.service_principal_client_secret
  aks_dns_prefix                      = "cx-${var.environment_name}-aks"
}