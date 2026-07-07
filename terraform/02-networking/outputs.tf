output "subnet_id" {
  description = "Identificador de la subred para la NIC de la VM"
  value       = azurerm_subnet.main.id
}

output "public_ip_id" {
  description = "Identificador de la IP publica"
  value       = azurerm_public_ip.main.id
}

output "public_ip_address" {
  description = "Direccion IP publica asignada"
  value       = azurerm_public_ip.main.ip_address
}

output "nsg_id" {
  description = "Identificador del grupo de seguridad de red"
  value       = azurerm_network_security_group.main.id
}
