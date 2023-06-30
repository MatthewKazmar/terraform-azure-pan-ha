## Deploys in an existing VNET with appropriate subnets. Login to the right tenant and subscription with Azure CLI.

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      #version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_virtual_network" "mynet" {
  name     = "my-network"
  location = "southcentralus"
}

resource "random_password" "fw" {
  length  = 31
  special = true
}

module "palo_southcentralus" {
  source = "github.com/MatthewKazmar/terraform-azure-pan-ha"

  name          = "pan-southcentralus"
  password      = random_password.fw.result
  resourcegroup = "pan-southcentralus"
  vnet          = data.azurerm_virtual_network.myvnet
  flex          = true
  subnet_names = {
    mgmt    = "mgmt",
    untrust = "untrust",
    trust   = "trust",
    ha      = "ha"
  }
}