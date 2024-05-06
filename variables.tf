variable "name" {
  description = "Base name of the firewall instances. Also used for avset and nsg."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the firewall's resource group."
  type        = string
  default     = ""
}

variable "location" {
  description = "Location of the firewall."
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
  default     = ""

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

variable "fwversion" {
  description = "Version of the firewall to deploy. For valid images: get-azvmimage -location eastus -publishername paloaltonetworks -offer vmseries-flex -skus byol"
  type        = string
  default     = "10.2.4"
}

variable "vnet_cidr" {
  description = "VNET address prefix"
  type        = string
}

variable "admin_cidrs" {
  description = "List of IPs for Mgmt NSG."
  type        = list(string)
  default     = ["3.94.47.185", "107.21.15.206"]
}

variable "public_loadbalancer_ports" {
  description = "Map of ports for Load Balancer rules. Specify <name>:udp/500 or <name>:tcp/443."
  type        = map(string)
  default     = {}
}

variable "ipsec_ports_dsr" {
  description = "Create the rules for IPSec udp/500/4500 with DSR."
  type        = bool
  default     = false
}

variable "panorama_ip" { type = string }
variable "template_name" { type = string }
variable "devicegroup_name" { type = string }
variable "vm_auth_key" { type = string }
variable "auth_code" { type = string }
variable "registration_pin_id" { type = string }
variable "registration_pin_value" { type = string }

locals {
  regions = [
    ["East US", "eastus", "EastUS", true],
    ["West US", "westus", "WestUS", false],
    ["North Central US", "northcentralus", "NorthCentralUS", false],
    ["South Central US", "southcentralus", "SouthCentralUS", true]
  ]

  region = flatten([for v in local.regions : v if contains(v, var.location)])
  name   = startswith(var.name, local.region[2]) ? var.name : "${local.region[2]}-${var.name}"

  zones  = local.region[3] ? var.availability_zones : null
  bits28 = 28 - split("/", var.vnet_cidr)[1]

  subnet_names = ["mgmt", "public", "internal", "ha"]
  subnets = { for i, v in local.subnet_names :
    v => cidrsubnet(var.vnet_cidr, local.bits28, i)
  }
  ilb_ip = cidrhost(local.subnets["internal"], 14)
  firewalls = { for i, v in var.availability_zones : "${local.name}-${i + 1}" => {
    az  = local.zones ? local.zones[i] : null
    pip = var.enable_untrust_pips
  } }

  bootstrap = { for k, v in local.firewalls : k => join(";", [
    "type=dhcp-client",
    "hostname=${k}",
    "panorama-server=${var.panorama_ip}",
    "tplname=${var.template_name}",
    "dgname=${var.devicegroup_name}",
    "dhcp-send-hostname=yes",
    "dhcp-send-client-id=yes",
    "dhcp-accept-server-hostname=no",
    "dhcp-accept-server-domain=no",
    "vm-auth-key=${var.vm_auth_key}",
    "authcodes=${var.auth_code}",
    "vm-series-auto-registration-pin-id=${var.registration_pin_id}",
    "vm-series-auto-registration-pin-value=${var.registration_pin_value}"
  ]) }

  plb = (length(var.public_loadbalancer_ports) > 0) || var.ipsec_ports_dsr ? 1 : 0
  plb_ipsec = var.ipsec_ports_dsr ? {
    "ipsec-udp-500-ike"    = 500
    "ipsec-udp-4500-nat-t" = 4500
  } : {}
}