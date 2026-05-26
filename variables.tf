variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "resource_group_name" {
  type        = string
  description = "Existing RG created by Template 1"
}

variable "aks_cluster_name" {
  type        = string
  description = "Existing AKS cluster name created by Template 1"
}

variable "vnet_name" {
  type        = string
  description = "Existing VNet name created by Template 1"
}

variable "name_prefix" {
  type        = string
  description = "Short prefix — must match what setup.sh used"
}

variable "alb_subnet_cidr" {
  type        = string
  default     = "10.10.3.0/24"
  description = "CIDR for ALB subnet — must not overlap AKS (10.10.0.0/23) or PSQL (10.10.2.0/27)"
}

variable "app_namespace" {
  type        = string
  default     = "demo"
  description = "Kubernetes namespace for the app"
}
