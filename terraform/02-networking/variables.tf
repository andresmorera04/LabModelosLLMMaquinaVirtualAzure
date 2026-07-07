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
  description = "Nombre del grupo de recursos creado por la capa foundation (output resource_group_name)"
  type        = string

  validation {
    condition     = length(trimspace(var.resource_group_name)) > 0
    error_message = "resource_group_name es obligatorio; obtengalo con: terraform -chdir=../01-foundation output -raw resource_group_name"
  }
}

variable "location" {
  description = "Region de Azure de la capa foundation (output location)"
  type        = string
  default     = "eastus2"
}

variable "my_ip" {
  description = "IP publica del desarrollador en formato CIDR (ej. 203.0.113.5/32) para restringir SSH y Ollama"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0)) && can(regex("/32$", var.my_ip))
    error_message = "my_ip debe ser una IP valida en formato CIDR /32, por ejemplo 203.0.113.5/32"
  }
}

variable "vnet_name" {
  description = "Nombre de la red virtual"
  type        = string
  default     = "vm-ollama-h100-vnet"
}

variable "subnet_name" {
  description = "Nombre de la subred"
  type        = string
  default     = "vm-ollama-h100-subnet"
}

variable "public_ip_name" {
  description = "Nombre de la IP publica"
  type        = string
  default     = "vm-ollama-h100-pip"
}

variable "nsg_name" {
  description = "Nombre del grupo de seguridad de red"
  type        = string
  default     = "vm-ollama-h100-nsg"
}

variable "vnet_address_space" {
  description = "Espacio de direcciones de la red virtual"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefixes" {
  description = "Prefijos de direcciones de la subred"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "ssh_port" {
  description = "Puerto SSH a permitir desde my_ip"
  type        = number
  default     = 22
}

variable "ollama_port" {
  description = "Puerto de la API de Ollama a permitir desde my_ip"
  type        = number
  default     = 11434
}

variable "tags" {
  description = "Etiquetas a aplicar a los recursos de red"
  type        = map(string)
  default     = {}
}
