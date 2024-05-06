resource "aws_secretsmanager_secret" "fw" {
  for_each = local.firewalls

  name = "virtualwan/panfw/${each.key}"
}

resource "random_string" "fw" {
  for_each = local.firewalls

  length  = 16
  special = true
}

resource "aws_secretsmanager_secret_version" "fw" {
  for_each = aws_secretsmanager_secret.fw

  secret_id = each.value.id
  secret_string = jsonencode({
    username   = "admin"
    password   = random_string.fw[each.key].result
    private_ip = azurerm_network_interface.mgmt[each.key].private_ip_address
    public_ip  = azurerm_public_ip.mgmt[each.key].ip_address
  })
}