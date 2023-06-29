variable "name" {
  description = "Base name of the firewall instances."
  type        = string
}

variable "resourcegroup" {
  description = "Name of the firewall's resource group."
  type        = string
}

variable "user" {
  description = "Admin user to create."
  type        = string
  default     = "panadmin"
}

variable "availability_zones" {
  description = "List of Availability Zone numbers - if the region supports them."
  type        = list(number)
  default     = [1, 2] #Pick the first two.
}

variable "size" {
  description = "Size of the Palo Alto VM."
  type        = string
  default     = "Standard_D3_v2"
}

variable "sku" {
  description = "SKU of VM-series firewall."
  type        = string
  default     = "byol"

  validation {
    condition     = contains(["byol", "bundle1", "bundle2"], var.sku)
    error_message = "Sku must be byol, bundle1, or bundle2."
  }
}

variable "fwversion" {
  description = "Version of the firewall to deploy. For valid images: get-azvmimage -location eastus -publishername paloaltonetworks -offer vmseries-flex -skus byol"
  type        = string
  default     = "10.1.9"
}

variable "vnet" {
  description = "Resource ID/URI of VNET."
  type = object({
    name                = string,
    resource_group_name = string,
    location            = string,
    id                  = string
  })
}

variable "subnet_names" {
  description = "Map of subnet names."
  type = object(
    {
      mgmt    = string,
      untrust = string,
      trust   = string,
      ha      = string
    }
  )
}

locals {
  az_regions = [
    "centralus",
    "eastus",
    "eastus2",
    "southcentralus",
    "westus2",
    "westus3"
  ]

  firewall_names = ["${var.name}]-fw1", "${var.name}-fw2"]

  firewalls = { for i, name in local.firewall_names : name => {
    az  = var.availability_zones[i],
    pip = ["${name}-mgmt-pip", "${name}-untrust-pip"],
    nic = {
      "${name}-mgmt"    = "${var.vnet.id}/subnets/${var.subnet_names["mgmt"]}",
      "${name}-untrust" = "${var.vnet.id}/subnets/${var.subnet_names["untrust"]}",
      "${name}-trust"   = "${var.vnet.id}/subnets/${var.subnet_names["trust"]}",
      "${name}-ha"      = "${var.vnet.id}/subnets/${var.subnet_names["ha"]}"
    }
  } }

  #Map of pip name -> az
  pips = merge([for k, v in local.firewalls : { for name in v.pip : name => v.az }]...)

  #Map of nic to subnet uri
  nics = merge([for k, v in local.firewalls : v.nic]...)
}