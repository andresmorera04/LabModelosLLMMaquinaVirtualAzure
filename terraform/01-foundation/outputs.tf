output "resource_group_name" {
  description = "Nombre del grupo de recursos creado"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "Identificador del grupo de recursos creado"
  value       = azurerm_resource_group.main.id
}

output "location" {
  description = "Region de Azure donde se creo el grupo de recursos"
  value       = azurerm_resource_group.main.location
}
