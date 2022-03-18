variable "k8s_cluster_name" {
  description = "The name of the AKS cluster to create"
  type        = string
}

variable "k8s_cluster_node_count" {
  description = "The number of kubernetes nodes to create for the k8s cluster"
  type        = number
  default     = 3
}

variable "k8s_vm_size" {
  description = "The Azure VM Size string i.e. Standard_D2_v2 or Standard_D8s_v3"
  type        = string
  default     = "Standard_D8s_v3"
}

variable "resource_group_location" {
  description = "The Azure region location for the resource group. Will also be used to set the location of all other resources"
  type        = string
  default     = "germanywestcentral"
}

variable "resource_group_name" {
  description = "The name for the resource group that will contain all AKS related resources"
  type        = string
}

variable "service_principal_client_id" {
  description = "USE TF_VAR_service_principal_client_id! The client ID of the service principal that will be used to create the AKS cluster."
  type        = string
}

variable "service_principal_client_secret" {
  description = "USE TF_VAR_service_principal_client_secret! The secret of the service principal that will be used to create the AKS cluster."
}