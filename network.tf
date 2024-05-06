resource "azurerm_virtual_network" "this" {
  name                = "${local.name}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_cidr]
  #dns_servers         = ["10.220.60.68", "10.221.60.68", "10.38.0.75"]
}

resource "azurerm_subnet" "this" {
  for_each             = local.subnets
  name                 = "pan-${each.key}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]
}

# Deploy Public IPs
resource "azurerm_public_ip" "mgmt" {
  for_each = local.firewalls

  name                = "${each.key}-mgmt"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  allocation_method   = "Static"

  #Specify a zone, if supported.
  zones = each.value["az"]

  lifecycle {
    ignore_changes        = [tags]
    create_before_destroy = true
  }
}

#Add Public IP to AWS Panorama SG and Mgmt interface whitelist
resource "aws_lambda_invocation" "fw_onboard" {
  function_name = "gwt-panorama-fw-onboard"

  input = jsonencode({ for k, v in azurerm_public_ip.mgmt : k => v.ip_address })

  lifecycle_scope = "CRUD"
}

resource "azurerm_public_ip" "public" {
  for_each = {for k, v in local.firewalls: k => v if v["pip"]}

  name                = "${each.key}-public"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  allocation_method   = "Static"

  #Specify a zone, if supported.
  zones = each.value["az"]

  lifecycle {
    ignore_changes        = [tags]
    create_before_destroy = true
  }
}