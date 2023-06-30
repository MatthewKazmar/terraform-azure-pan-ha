output "credentials" {
  value = {
    username = var.user
    password = var.password
  }
}

output "management_public_ips" {
  value = { for k, v in azurerm_azurerm_public_ip.pip: k => v if endswith(k, "-mgmt") }
}