# ============================================================
# Template 2 — Grouper ALB POC
#
# Template 1 already created: RG, VNet, AKS subnets, AKS, ACR, PostgreSQL
#
# This template is split into two targeted applies via -target:
#
#   Stage 1 (GitHub Actions — job: azure_infra):
#     Creates ALB subnet, ALB identity, federated credential,
#     ALB resource, ALB association
#
#   [setup.sh runs between stages — assigns roles, waits for propagation]
#
#   Stage 2 (GitHub Actions — job: app_deploy):
#     Installs ALB controller Helm chart, deploys nginx app,
#     Gateway, HTTPRoute
# ============================================================

# ----- Read existing resources from Template 1 -----

data "azurerm_resource_group" "grouper" {
  name = var.resource_group_name
}

data "azurerm_kubernetes_cluster" "grouper" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.grouper.name
}

data "azurerm_virtual_network" "grouper" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.grouper.name
}

# ============================================================
# STAGE 1 — Azure resources
# ============================================================

resource "azurerm_subnet" "alb" {
  name                 = "snet-alb"
  resource_group_name  = data.azurerm_resource_group.grouper.name
  virtual_network_name = data.azurerm_virtual_network.grouper.name
  address_prefixes     = [var.alb_subnet_cidr]

  delegation {
    name = "alb-delegation"
    service_delegation {
      name    = "Microsoft.ServiceNetworking/trafficControllers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_user_assigned_identity" "alb" {
  name                = "mi-alb-${var.name_prefix}"
  resource_group_name = data.azurerm_resource_group.grouper.name
  location            = data.azurerm_resource_group.grouper.location

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_federated_identity_credential" "alb" {
  name                = "alb-federated"
  resource_group_name = data.azurerm_resource_group.grouper.name
  parent_id           = azurerm_user_assigned_identity.alb.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = data.azurerm_kubernetes_cluster.grouper.oidc_issuer_url
  subject  = "system:serviceaccount:azure-alb-system:alb-controller-sa"
}

resource "azapi_resource" "alb" {
  type      = "Microsoft.ServiceNetworking/trafficControllers@2024-05-01-preview"
  name      = "alb-${var.name_prefix}"
  parent_id = data.azurerm_resource_group.grouper.id
  location  = data.azurerm_resource_group.grouper.location

  body = {
    properties = {}
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azapi_resource" "alb_association" {
  type      = "Microsoft.ServiceNetworking/trafficControllers/associations@2024-05-01-preview"
  name      = "alb-association"
  parent_id = azapi_resource.alb.id
  location  = data.azurerm_resource_group.grouper.location

  body = {
    properties = {
      associationType = "subnets"
      subnet = {
        id = azurerm_subnet.alb.id
      }
    }
  }

  depends_on = [azapi_resource.alb]

  lifecycle {
    ignore_changes = [tags]
  }
}

# ============================================================
# STAGE 2 — Helm + App (runs after setup.sh assigns roles)
# ============================================================

resource "helm_release" "alb_controller" {
  name             = "alb-controller"
  namespace        = "azure-alb-system"
  create_namespace = true

  repository = "oci://mcr.microsoft.com/application-lb/charts"
  chart      = "alb-controller"

  set {
    name  = "albController.podIdentity.clientID"
    value = azurerm_user_assigned_identity.alb.client_id
  }

  depends_on = [
    azurerm_federated_identity_credential.alb,
    azapi_resource.alb_association,
  ]
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels    = { app = "nginx" }
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = { app = "nginx" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port { container_port = 80 }
        }
      }
    }
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = { app = "nginx" }
    port {
      port        = 80
      target_port = 80
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "demo-gateway"
      namespace = kubernetes_namespace.app.metadata[0].name
      annotations = {
        "alb.networking.azure.io/alb-id" = azapi_resource.alb.id
      }
    }
    spec = {
      gatewayClassName = "azure-alb-external"
      listeners = [{
        name     = "http"
        port     = 80
        protocol = "HTTP"
      }]
    }
  }

  lifecycle {
    replace_triggered_by = [azapi_resource.alb]
  }

  depends_on = [helm_release.alb_controller, azapi_resource.alb]
}

resource "kubernetes_manifest" "httproute" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "demo-route"
      namespace = kubernetes_namespace.app.metadata[0].name
    }
    spec = {
      parentRefs = [{ name = "demo-gateway" }]
      rules = [{
        backendRefs = [{ name = "nginx-service", port = 80 }]
      }]
    }
  }

  depends_on = [kubernetes_manifest.gateway]
}
