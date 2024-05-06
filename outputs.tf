output "credentials" {
  value = {
    username = var.user
    password = var.password
  }
}

output "management_public_ips" {
  value = azurerm_public_ip.mgmt
}