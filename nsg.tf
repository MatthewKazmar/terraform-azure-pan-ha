resource "azurerm_network_security_group" "this" {
  for_each = local.subnets

  name                = each.value
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_network_security_rule" "mgmt_in_1" {
  name                        = "mgmt-in-allow"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.admin_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this["mgmt"].name
}

resource "azurerm_network_security_rule" "mgmt_in_2" {
  name                         = "mgmt-in-peers"
  priority                     = 110
  direction                    = "Inbound"
  access                       = "Allow"
  protocol                     = "*"
  source_port_range            = "*"
  destination_port_range       = "*"
  source_address_prefixes      = azurerm_subnet.fw["mgmt"].address_prefixes
  destination_address_prefixes = azurerm_subnet.fw["mgmt"].address_prefixes
  resource_group_name          = azurerm_resource_group.this.name
  network_security_group_name  = azurerm_network_security_group.this["mgmt"].name
}

resource "azurerm_network_security_rule" "mgmt_in_deny" {
  name                        = "mgmt-in-deny"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this["mgmt"].name
}

resource "azurerm_network_security_rule" "allowall_in" {
  name                        = "allow-all-in"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = azurerm_network_security_group.this["trust"].name
}

resource "azurerm_network_security_rule" "allowall_out" {
  for_each = { for k, v in azurerm.azurerm_network_security_group.this : k => v if contains(["public", "internal"], split(k, "-")[1]) }

  name                        = "allow-all-out"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.this.name
  network_security_group_name = each.value.name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = azurerm_network_security_group.this

  subnet_id = azurerm_subnet.this[each.key].id
  #subnet_id                 = azurerm_subnet.fw[each.key].id
  network_security_group_id = each.value.id
}