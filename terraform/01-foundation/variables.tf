variable "subscription_id" {
  description = "Identificador de la suscripcion de Azure"
  type        = string
}

variable "client_id" {
  description = "Client ID del Service Principal. Si se omite, se usa ARM_CLIENT_ID"
  type        = string
  default     = null
  sensitive   = true
}

variable "client_secret" {
  description = "Client Secret del Service Principal. Si se omite, se usa ARM_CLIENT_SECRET"
  type        = string
  default     = null
  sensitive   = true
}

variable "tenant_id" {
  description = "Tenant ID de Azure AD. Si se omite, se usa ARM_TENANT_ID"
  type        = string
  default     = null
  sensitive   = true
}

variable "resource_group_name" {
  description = "Nombre del grupo de recursos a crear"
  type        = string
}

variable "location" {
  description = "Region de Azure donde crear el grupo de recursos"
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Etiquetas a aplicar al grupo de recursos"
  type        = map(string)
  default     = {}
}
