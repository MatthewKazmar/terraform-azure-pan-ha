resource "azurerm_public_ip" "plb" {
  count = local.plb

  name                = "${local.name}-PublicLoadBalancer-pip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  allocation_method   = "Static"

  #Specify a zone, if supported.
  zones = local.zones

  lifecycle {
    ignore_changes        = [tags]
    create_before_destroy = true
  }
}

resource "azurerm_lb" "plb" {
  count = local.plb

  name                = "${local.name}-PublicLoadBalancer"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = one(azurerm_public_ip.plb).id
  }
}

resource "azurerm_lb_backend_address_pool" "plb" {
  count           = local.plb
  loadbalancer_id = one(azurerm_lb.plb).id
  name            = "backend"
}

resource "azurerm_network_interface_backend_address_pool_association" "plb" {
  for_each = { for k, v in azurerm_network_interface.eth1_1 : k => v if local.plb }

  network_interface_id    = each.value.id
  ip_configuration_name   = each.value.ip_configuration[0].name
  backend_address_pool_id = one(azurerm_lb_backend_address_pool.plb).id
}

resource "azurerm_lb_rule" "plb" {
  for_each = var.public_loadbalancer_ports

  loadbalancer_id                = one(azurerm_lb.plb).id
  name                           = each.key
  protocol                       = split("/", each.value)[0]
  frontend_port                  = split("/", each.value)[1]
  backend_port                   = split("/", each.value)[1]
  frontend_ip_configuration_name = one(azurerm_lb.plb).frontend_ip_configuration[0].name
  backend_address_pool_ids       = [one(azurerm_lb_backend_address_pool.plb).id]
  probe_id                       = one(azurerm_lb_probe.plb).id
}

resource "azurerm_lb_rule" "plb_ipsec" {
  for_each = local.plb_ipsec

  loadbalancer_id                = one(azurerm_lb.plb).id
  name                           = each.key
  protocol                       = "udp"
  frontend_port                  = each.value
  backend_port                   = each.value
  frontend_ip_configuration_name = one(azurerm_lb.plb).frontend_ip_configuration[0].name
  backend_address_pool_ids       = [one(azurerm_lb_backend_address_pool.plb).id]
  probe_id                       = one(azurerm_lb_probe.plb).id
  enable_floating_ip             = true
}

resource "azurerm_lb_probe" "plb" {
  loadbalancer_id = one(azurerm_lb.plb).id
  name            = "tcp-443"
  port            = 443
}