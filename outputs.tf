output "firewalls" {
  value = {
    username = var.user
    firewalls = { for k, v in azurerm_public_ip.mgmt : k =>
      {
        mgmt_public_ip   = v.ip_address
        mgmt_internal_ip = azurerm_network_interface.mgmt[k].private_ip_address
        password         = random_string.fw[k].result
      }
    }
    public_load_balancer_ip   = azurerm_public_ip.plb.ip_address
    internal_load_balancer_ip = local.ilb_ip
  }
}