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

variable "subnet_id" {
  description = "Identificador de la subred creada por la capa networking (output subnet_id)"
  type        = string

  validation {
    condition     = length(trimspace(var.subnet_id)) > 0
    error_message = "subnet_id es obligatorio; obtengalo con: terraform -chdir=../02-networking output -raw subnet_id"
  }
}

variable "public_ip_id" {
  description = "Identificador de la IP publica creada por la capa networking (output public_ip_id)"
  type        = string

  validation {
    condition     = length(trimspace(var.public_ip_id)) > 0
    error_message = "public_ip_id es obligatorio; obtengalo con: terraform -chdir=../02-networking output -raw public_ip_id"
  }
}

variable "public_ip_address" {
  description = "Direccion de la IP publica creada por la capa networking (output public_ip_address)"
  type        = string

  validation {
    condition     = length(trimspace(var.public_ip_address)) > 0
    error_message = "public_ip_address es obligatorio; obtengalo con: terraform -chdir=../02-networking output -raw public_ip_address"
  }
}

variable "nic_name" {
  description = "Nombre de la interfaz de red (NIC) de la VM"
  type        = string
  default     = "vm-ollama-h100-nic"
}

variable "vm_name" {
  description = "Nombre de la maquina virtual"
  type        = string
  default     = "vm-ollama-h100"
}

variable "vm_size" {
  description = "Tamano (SKU) de la maquina virtual GPU"
  type        = string
  default     = "Standard_NC40ads_H100_v5"
}

variable "admin_username" {
  description = "Nombre del usuario administrador de la VM"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Ruta local al archivo de llave publica SSH usado para autenticar al usuario administrador"
  type        = string

  validation {
    condition     = fileexists(var.ssh_public_key_path)
    error_message = "ssh_public_key_path debe apuntar a un archivo de llave publica SSH existente y legible"
  }
}

variable "image_publisher" {
  description = "Publisher de la imagen del sistema operativo"
  type        = string
  default     = "microsoft-dsvm"
}

variable "image_offer" {
  description = "Offer de la imagen del sistema operativo"
  type        = string
  default     = "ubuntu-hpc"
}

variable "image_sku" {
  description = "SKU de la imagen del sistema operativo"
  type        = string
  default     = "2404"
}

variable "image_version" {
  description = "Version de la imagen del sistema operativo"
  type        = string
  default     = "latest"
}

variable "os_disk_size_gb" {
  description = "Tamano en GB del disco del sistema operativo"
  type        = number
  default     = 64
}

variable "os_disk_storage_account_type" {
  description = "Tipo de cuenta de almacenamiento del disco del sistema operativo"
  type        = string
  default     = "StandardSSD_LRS"
}

variable "accept_marketplace_terms" {
  description = "Si es true, acepta los terminos de la imagen Marketplace antes de crear la VM"
  type        = bool
  default     = false
}

variable "image_plan_name" {
  description = "Nombre del plan de Marketplace para la imagen, si difiere del SKU. Solo se usa cuando accept_marketplace_terms es true"
  type        = string
  default     = null
}

variable "tags" {
  description = "Etiquetas a aplicar a los recursos de computo"
  type        = map(string)
  default     = {}
}
