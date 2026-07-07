# Plan de implementación

- [x] 1. Crear directorio de la capa y configurar el provider azurerm
  - Crear el directorio `terraform/02-networking/`
  - Crear `providers.tf` con bloque `terraform` (restricciones `required_version >= 1.5` y provider `azurerm >= 4.0`) y bloque `provider "azurerm"` con `resource_provider_registrations = "none"`, autenticación vía variables de Service Principal con fallback a variables de entorno `ARM_*`
  - Observable: `terraform init` ejecutado en `terraform/02-networking/` completa exitosamente sin errores
  - _Requirements: 6.1_

- [x] 2. Declarar todas las variables de entrada con tipos, descripciones y validaciones
  - Variables de autenticación (`subscription_id` obligatoria, `client_id`/`client_secret`/`tenant_id` opcionales con `sensitive = true` y `default = null`)
  - Variables de conexión con `foundation` (`resource_group_name` obligatoria con validación de cadena no vacía, `location` con default `"eastus2"`)
  - Variables de red (`vnet_name`, `subnet_name`, `vnet_address_space`, `subnet_address_prefixes`) con defaults seguros
  - Variables de seguridad (`my_ip` obligatoria con validación de formato CIDR `/32`, `ssh_port` default 22, `ollama_port` default 11434)
  - Variables de nombrado y etiquetas (`public_ip_name`, `nsg_name` con defaults, `tags` default `{}`)
  - Observable: `terraform validate` pasa sin errores; Terraform detiene la ejecución si falta `my_ip`, `subscription_id` o `resource_group_name`
  - _Requirements: 1.1, 1.3, 4.3, 4.4, 6.1, 6.2, 6.5_

- [x] 3. Implementar recursos de infraestructura de red
  - Crear `azurerm_virtual_network` con `address_space` y `tags` de variables, nombre de variable
  - Crear `azurerm_subnet` con `address_prefixes` de variable, referenciando la VNet
  - Crear `azurerm_public_ip` con `sku = "Standard"` y `allocation_method = "Static"`, nombre y tags de variables
  - Crear `azurerm_network_security_group` con dos reglas inline: `Allow-SSH` (puerto `var.ssh_port`, origen `var.my_ip`) y `Allow-Ollama` (puerto `var.ollama_port`, origen `var.my_ip`); sin reglas con origen `*` ni `Internet` para esos puertos
  - Crear `azurerm_subnet_network_security_group_association` vinculando el NSG a la subred
  - Todos los recursos creados dentro del grupo de recursos y región provistos por variables de `foundation`
  - Observable: `terraform plan` con variables válidas muestra 5 recursos a crear (VNet, Subnet, IP pública, NSG, asociación NSG-subred)
  - _Requirements: 1.2, 2.1, 2.3, 2.4, 3.1, 3.2, 3.3, 4.1, 4.2, 4.5, 4.6_

- [x] 4. Exponer outputs de red para consumo de la capa compute
  - Declarar outputs `subnet_id`, `public_ip_id`, `public_ip_address`, `nsg_id` en `outputs.tf`
  - Nombres estables en `snake_case`, información no sensible
  - Observable: tras `terraform apply`, `terraform output` imprime los cuatro valores correctamente
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 5. (P) Crear plantilla de variables de ejemplo versionada
  - Crear `terraform.tfvars.example` con todas las variables y valores placeholder
  - Incluir comentarios sobre cómo obtener `resource_group_name` y `location` desde outputs de `foundation`
  - Incluir placeholder para `my_ip` con nota sobre cómo obtenerla (`curl -s https://api.ipify.org` + `/32`)
  - Indicar que las credenciales `ARM_*` pueden configurarse como variables de entorno
  - El archivo `terraform.tfvars` real con valores del entorno queda excluido del repositorio vía `.gitignore` existente
  - Observable: `terraform.tfvars.example` presente en el repositorio con todas las variables documentadas y sin valores reales
  - _Requirements: 6.3, 6.4_
  - _Depends: 2_
  - _Boundary: VariablesTemplate_

- [x] 6. Validar estructura, formato e idempotencia de la capa
  - `terraform validate` pasa sin errores en `terraform/02-networking/`
  - `terraform fmt -check` pasa sin diferencias de formato
  - Archivos siguen convenciones de nombrado: `kebab-case.tf`, variables en `snake_case`
  - Código de infraestructura separado de valores de configuración (archivos `.tf` vs `terraform.tfvars`)
  - Un segundo `terraform plan` tras `apply` exitoso sin cambios de configuración reporta cero cambios
  - Si un recurso gestionado desaparece externamente, el siguiente `apply` lo recrea sin intervención manual
  - Observable: todos los comandos de validación pasan exitosamente; la capa cumple las convenciones del steering del proyecto
  - _Requirements: 2.2, 7.1, 7.2, 7.3, 7.4_
