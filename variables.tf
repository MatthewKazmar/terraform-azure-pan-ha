variable "name" {
  description = "Base name of the firewall instances. Also used for avset and nsg."
  type        = string
}

variable "name_override" {
  description = "Use to directly specify firewall pair names."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = (length(var.name_override) == 2 || length(var.name_override) == 0)
    error_message = "If you override the firewall names, two entries, please."
  }
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

variable "password" {
  description = "Admin user password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.password) <= 31
    error_message = "The PAN admin password must be 31 characters or less. Or enjoy the bootloop."
  }
}

variable "availability_zones" {
  description = "List of Availability Zone numbers - if the region supports them."
  type        = list(number)
  default     = [1, 2] #Pick the first two.
}

variable "apply_nsgs" {
  description = "Set to false to skip NSG deployment."
  type        = bool
  default     = true
}

variable "enable_untrust_pips" {
  description = "Create and apply pips to untrust interface."
  type        = bool
  default     = true
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

variable "flex" {
  description = "Use Flex license model."
  type        = bool
  default     = false
}

variable "fwversion" {
  description = "Version of the firewall to deploy. For valid images: get-azvmimage -location eastus -publishername paloaltonetworks -offer vmseries-flex -skus byol"
  type        = string
  default     = "9.1.0"
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

variable "bootstrap_account_name" {
  description = "Bootstrap storage account"
  type        = string
  default     = ""
}

variable "bootstrap_account_key" {
  description = "Bootstrap account key"
  type        = string
  default     = ""
}

variable "bootstrap_share_name" {
  description = "Bootstrap share name"
  type        = string
  default     = ""
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

  fwversion = var.fwversion == "" ? var.flex == true ? "10.1.9" : "9.1.0" : var.fwversion
  fwoffer   = var.flex == true ? "vmseries-flex" : "vmseries1"

  firewall_names = length(var.name_override) == 0 ? ["${var.name}-fw1", "${var.name}-fw2"] : var.name_override

  firewalls = { for i, name in local.firewall_names : name => {
    az  = var.availability_zones[i],
    pip = var.enable_untrust_pips ? ["${name}-mgmt-pip", "${name}-untrust-pip"] : ["${name}-mgmt-pip"],
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

  #bootstrap
  customdata = base64encode("storage-accounts=${var.bootstrap_account_name},access-key=${var.bootstrap_account_key},file-share=${var.bootstrap_share_name},share-directory=")
}