terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstateaksalb001"
    container_name       = "tfstate"
    key                  = "grouper-alb-poc.tfstate"
  }
}
