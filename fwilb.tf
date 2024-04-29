resource "azurerm_lb" "ilb" {
  name                = "${local.name}-InternalLoadBalancer"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "frontend"
    private_ip_address            = local.ilb_ip
    private_ip_address_allocation = "static"
    subnet_id                     = azurerm_subnet.fw["internal"].id
  }
}

resource "azurerm_lb_backend_address_pool" "ilb" {
  loadbalancer_id = azurerm_lb.ilb.id
  name            = "backend"
}

resource "azurerm_network_interface_backend_address_pool_association" "ilb" {
  for_each = azurerm_network_interface.eth1_1

  network_interface_id    = each.value.id
  ip_configuration_name   = each.value.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.ilb.id
}

resource "azurerm_lb_rule" "ilb" {
  loadbalancer_id                = azurerm_lb.ilb.id
  name                           = "harule"
  protocol                       = "All"
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = azurerm_lb.ilb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.ilb.id]
  probe_id                       = azurerm_lb_probe.ilb.id
}

resource "azurerm_lb_probe" "ilb" {
  loadbalancer_id = azurerm_lb.ilb.id
  name            = "tcp-443"
  port            = 443
}