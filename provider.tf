terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.2.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.0.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.32.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.1"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azapi" {}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.grouper.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.grouper.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.grouper.kube_config[0].cluster_ca_certificate)
  }
}
