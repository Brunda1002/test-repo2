# ============================================================
# Calstate Template 2 — Grouper ALB POC
# Stage 1 ONLY
# Uses EXISTING App Gateway subnet from infra
# ============================================================

# ----- Read existing calstate infra -----

data "azurerm_resource_group" "grouper" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "grouper" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.grouper.name
}

data "azurerm_kubernetes_cluster" "grouper" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.grouper.name
}

# ----- Existing App Gateway subnet from infra -----

data "azurerm_subnet" "appgw" {
  name                 = "grouper-dev-tf-appgw-subnet"
  virtual_network_name = data.azurerm_virtual_network.grouper.name
  resource_group_name  = data.azurerm_resource_group.grouper.name
}

# ----- ALB Managed Identity -----

resource "azurerm_user_assigned_identity" "alb" {
  name                = "mi-alb-${var.name_prefix}"
  resource_group_name = data.azurerm_resource_group.grouper.name
  location            = data.azurerm_resource_group.grouper.location
}

# ----- Workload Identity Federation -----

resource "azurerm_federated_identity_credential" "alb" {
  name                = "alb-federated"
  resource_group_name = data.azurerm_resource_group.grouper.name
  parent_id           = azurerm_user_assigned_identity.alb.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = data.azurerm_kubernetes_cluster.grouper.oidc_issuer_url
  subject  = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}

# ----- ALB Traffic Controller -----

resource "azapi_resource" "alb" {
  type      = "Microsoft.ServiceNetworking/trafficControllers@2024-05-01-preview"
  name      = "alb-${var.name_prefix}"
  parent_id = data.azurerm_resource_group.grouper.id
  location  = data.azurerm_resource_group.grouper.location

  body = {
    properties = {}
  }
}

# ----- Associate ALB with EXISTING App Gateway subnet -----

resource "azapi_resource" "alb_association" {
  type      = "Microsoft.ServiceNetworking/trafficControllers/associations@2024-05-01-preview"
  name      = "alb-association"
  parent_id = azapi_resource.alb.id
  location  = data.azurerm_resource_group.grouper.location

  body = {
    properties = {
      associationType = "subnets"
      subnet = {
        id = data.azurerm_subnet.appgw.id
      }
    }
  }
}