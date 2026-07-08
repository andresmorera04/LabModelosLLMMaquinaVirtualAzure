output "vm_name" {
  description = "Nombre de la maquina virtual GPU creada, consumido por la fase de configuracion (Ola 4)"
  value       = azurerm_linux_virtual_machine.main.name
}

output "vm_public_ip" {
  description = "Direccion IP publica de la VM, usada para la conexion SSH de la fase de configuracion"
  value       = var.public_ip_address
}

output "admin_username" {
  description = "Nombre del usuario administrador configurado en la VM para el acceso SSH"
  value       = var.admin_username
}
