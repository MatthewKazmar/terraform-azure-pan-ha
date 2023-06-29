# Deploy PAN VM-Series
data "azurerm_virtual_network" "vnet" {
  name                = split("/", var.vnet)[8]
  resource_group_name = split("/", var.vnet)[4]
}

resource "azurerm_resource_group" "rg" {
  name     = var.resourcegroup
  location = data.azurerm_virtual_network.vnet.location
}

# Deploy if avset is not supported.
resource "azurerm_availability_set" "avset" {
  count = contains(local.az_regions, azurerm_resource_group.rg.location) ? 0 : 1

  name                = "${var.name}-avset"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Deploy Public IPs
resource "azurerm_public_ip" "pip" {
  for_each = local.pips

  name                = each.key
  resource_group_name = azurerm_availability_set.fw.name
  location            = azurerm_availability_set.fw.location
  sku                 = "standard"
  allocation_method   = "static"

  #Specify a zone, if supported.
  zones = contains(local.az_regions, azurerm_resource_group.rg.location) ? [each.value] : null
}

# Deploy NICs
resource "azurerm_network_interface" "nic" {
  for_each = local.nics

  name                = each.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconf1"
    subnet_id                     = each.value
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = contains(keys(azurerm_public_ip.pip), "${each.name}-pip") ? azurerm_public_ip.pip["${each.name}-pip"].id : null
  }

  enable_accelerated_networking = true
  enable_ip_forwarding          = strcontains(each.name, "trust")
}

# Basic NSG
resource "azurerm_network_security_group" "mgmt" {
  name = "${var.name}-mgmt"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_group" "untrust" {
  name = "${var.name}-untrust"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet_network_security_group_association" "mgmt" {
  subnet_id = "${var.vnet}/subnets/${var.subnet_names["mgmt"]}"
  network_security_group_id = azurerm_network_security_group.mgmt.id
}

resource "azurerm_subnet_network_security_group_association" "untrust" {
  subnet_id = "${var.vnet}/subnets/${var.subnet_names["untrust"]}"
  network_security_group_id = azurerm_network_security_group.untrust.id
}

# Deploy firewalls
resource "azurerm_linux_virtual_machine" "fw" {
  for_each = local.firewalls

  name                = each.key
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.size

  admin_username = var.user
  admin_password = "mytemppassword"

  network_interface_ids = [for nic in each.value.nic : azurerm_network_interface.nic[nic].id]

  availability_set_id = contains(local.az_regions, azurerm_resource_group.rg.location) ? null : azurerm_availability_set.avset.id
  zones               = contains(local.az_regions, azurerm_resource_group.rg.location) ? [each.value] : null

  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "paloaltonetworks"
    offer     = "vmseries-flex"
    sku       = var.sku
    version   = var.fwversion
  }
}