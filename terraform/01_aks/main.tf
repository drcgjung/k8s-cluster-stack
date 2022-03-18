resource "azurerm_resource_group" "aks_resource_group" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = var.k8s_cluster_name
  location            = azurerm_resource_group.aks_resource_group.location
  resource_group_name = azurerm_resource_group.aks_resource_group.name

  default_node_pool {
    name       = "default"
    vm_size    = var.k8s_vm_size
    node_count = var.k8s_cluster_node_count
  }

  service_principal {
    client_id     = var.service_principal_client_id
    client_secret = var.service_principal_client_secret
  }
}