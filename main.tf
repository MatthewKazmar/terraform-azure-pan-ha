# Deploy PAN VM-Series
resource "azurerm_marketplace_agreement" "pan" {
  publisher = "paloaltonetworks"
  offer     = local.fwoffer
  plan      = var.sku
}

# resource "azurerm_resource_group" "rg" {
#   name     = var.resourcegroup
#   location = var.vnet.location
# }

# Deploy if avset is not supported.
resource "azurerm_availability_set" "avset" {
  count = contains(local.az_regions, var.vnet.location) ? 0 : 1

  name                = "${var.name}-avset"
  location            = var.vnet.location
  resource_group_name = var.resourcegroup
}

# Deploy Public IPs
resource "azurerm_public_ip" "pip" {
  for_each = local.pips

  name                = each.key
  location            = var.vnet.location
  resource_group_name = var.resourcegroup
  sku                 = "Standard"
  allocation_method   = "Static"

  #Specify a zone, if supported.
  zones = contains(local.az_regions, var.vnet.location) ? [each.value] : null
}

# Deploy NICs
resource "azurerm_network_interface" "nic" {
  for_each = local.nics

  name                = each.key
  location            = var.vnet.location
  resource_group_name = var.resourcegroup

  ip_configuration {
    name                          = "ipconf1"
    subnet_id                     = each.value
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = contains(keys(azurerm_public_ip.pip), "${each.key}-pip") ? azurerm_public_ip.pip["${each.key}-pip"].id : null
  }

  enable_accelerated_networking = true
  enable_ip_forwarding          = strcontains(each.key, "trust")
}

# Basic NSG
resource "azurerm_network_security_group" "nsg" {
  count = var.apply_nsgs ? 1 : 0

  name                = "${var.name}-nsg"
  location            = var.vnet.location
  resource_group_name = var.resourcegroup
}

resource "azurerm_network_security_rule" "allowall-in" {
  count = var.apply_nsgs ? 1 : 0

  name                        = "allow-all-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = one(azurerm_network_security_group.nsg).resource_group_name
  network_security_group_name = one(azurerm_network_security_group.nsg).name
}

resource "azurerm_network_security_rule" "allowall-out" {
  count = var.apply_nsgs ? 1 : 0

  name                        = "allow-all-out"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = one(azurerm_network_security_group.nsg).resource_group_name
  network_security_group_name = one(azurerm_network_security_group.nsg).nsg.name
}

resource "azurerm_subnet_network_security_group_association" "nsg" {
  for_each = var.apply_nsgs ? toset(["mgmt", "untrust", "trust"]) : toset([])

  subnet_id                 = "${var.vnet.id}/subnets/${var.subnet_names[each.value]}"
  network_security_group_id = one(azurerm_network_security_group.nsg).id
}

# Deploy firewalls
resource "azurerm_linux_virtual_machine" "fw" {
  for_each = local.firewalls

  name                = each.key
  resource_group_name = var.resourcegroup
  location            = var.vnet.location
  size                = var.size

  admin_username                  = var.user
  admin_password                  = var.password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.nic["${each.key}-mgmt"].id,
    azurerm_network_interface.nic["${each.key}-untrust"].id,
    azurerm_network_interface.nic["${each.key}-trust"].id,
    azurerm_network_interface.nic["${each.key}-ha"].id
  ]

  availability_set_id = contains(local.az_regions, var.vnet.location) ? null : one(azurerm_availability_set.avset).id
  zone                = contains(local.az_regions, var.vnet.location) ? each.value.az : null

  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "paloaltonetworks"
    offer     = local.fwoffer
    sku       = var.sku
    version   = local.fwversion
  }

  plan {
    name      = var.sku
    product   = local.fwoffer
    publisher = "paloaltonetworks"
  }

  boot_diagnostics {}

  depends_on = [azurerm_marketplace_agreement.pan]
}