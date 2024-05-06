# Deploy PAN VM-Series

# Resource Group
resource "azurerm_resource_group" "this" {
  name     = "${local.name}-rg"
  location = var.location
}

# Deploy if zones is not supported.
resource "azurerm_availability_set" "this" {
  count = local.zones ? 0 : 1

  name                = "${var.name}-avset"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  lifecycle {
    ignore_changes = [tags]
  }
}


# Deploy NICs
resource "azurerm_network_interface" "mgmt" {
  for_each = local.firewalls

  name                = "${each.key}-mgmt"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this["mgmt"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgmt[each.key].id
  }

  enable_accelerated_networking = true
  enable_ip_forwarding          = true
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_interface" "eth1_1" {
  for_each = local.firewalls

  name                = "${each.key}-intenral"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this["public"].id
    private_ip_address_allocation = "Dynamic"
  }

  enable_accelerated_networking = true
  enable_ip_forwarding          = true

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_interface" "eth1_2" {
  for_each = local.firewalls

  name                = "${each.key}-public"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this["internal"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = each.value["pip"] ? azurerm_public_ip.public[each.key].id : null
  }

  enable_accelerated_networking = true
  enable_ip_forwarding          = true
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_interface" "ha" {
  for_each = local.firewalls

  name                = "${each.key}-ha"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.this["ha"].id
    private_ip_address_allocation = "Dynamic"
  }

  enable_accelerated_networking = true
  enable_ip_forwarding          = true

  lifecycle {
    ignore_changes = [tags]
  }
}

# Deploy firewalls
resource "azurerm_linux_virtual_machine" "fw" {
  for_each = local.firewalls

  name                = each.key
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.size

  admin_username                  = var.user
  admin_password                  = var.password
  disable_password_authentication = false

  custom_data = base64encode(local.bootstrap[each.key])

  network_interface_ids = [
    azurerm_network_interface.mgmt[each.key].id,
    azurerm_network_interface.public[each.key].id,
    azurerm_network_interface.internal[each.key].id,
    azurerm_network_interface.ha[each.key].id
  ]

  availability_set_id = try(one(azurerm_availability_set.avset).id, null)
  zone                = each.value["az"]

  os_disk {
    name                 = "${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "paloaltonetworks"
    offer     = "vmseries-flex"
    sku       = "byol"
    version   = var.fwversion
  }

  plan {
    name      = "byol"
    product   = "vmseries-flex"
    publisher = "paloaltonetworks"
  }

  boot_diagnostics {}

  lifecycle {
    ignore_changes = [tags]
  }

}