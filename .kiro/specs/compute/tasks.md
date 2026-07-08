# Implementation Plan

- [ ] 1. Base de la capa: providers y variables de entrada
- [x] 1.1 Configurar providers y autenticación del directorio 03-compute
  - Crear `terraform/03-compute/providers.tf` replicando textualmente el patrón de `01`/`02`: bloque `terraform` con `required_version >= 1.5`, `azurerm >= 4.0` y `provider "azurerm"` con `features {}` y `resource_provider_registrations = "none"`
  - El provider referencia las variables de autenticación (`subscription_id`, `client_id`, `client_secret`, `tenant_id`) con fallback a `ARM_*`
  - Observable: `providers.tf` es idéntico en estructura al de `02-networking`; tras declarar variables (1.2), `terraform init` en `terraform/03-compute/` descarga `azurerm >= 4.0` sin errores
  - _Requirements: 7.1_
- [x] 1.2 Declarar todas las variables de entrada con tipo, descripción y validación
  - Variables de autenticación: `subscription_id` (sin default), `client_id`/`client_secret`/`tenant_id` (default `null`, `sensitive`)
  - Variables de consumo de capas previas con `validation` no vacía (`length(trimspace(...)) > 0`) y `error_message` que apunta a `terraform -chdir=../01-foundation output -raw <name>` (`resource_group_name`, `location`) y `../02-networking output -raw <name>` (`subnet_id`, `public_ip_id`, `public_ip_address`)
  - Variables de recursos con default `prefijo-funcion` (`nic_name`, `vm_name`), cómputo (`vm_size`), imagen (`image_publisher`/`image_offer`/`image_sku`/`image_version`), disco (`os_disk_size_gb`, `os_disk_storage_account_type`), autenticación (`admin_username`)
  - `ssh_public_key_path` sin default y con `validation` usando `fileexists(var.ssh_public_key_path)` y `error_message` claro
  - `accept_marketplace_terms` (bool, default `false`), `image_plan_name` (string, default `null`) y `tags` (map(string), default `{}`)
  - Observable: `terraform validate` reconoce todas las variables; una variable requerida sin valor (p. ej. `subnet_id` vacío) detiene el `plan` con el `error_message` que cita el comando de recuperación
  - _Requirements: 1.1, 1.2, 1.4, 5.4, 7.1, 7.2, 7.5_

- [ ] 2. Recursos Terraform de cómputo (main.tf)
- [x] 2.1 Crear la interfaz de red (NIC)
  - Declarar `azurerm_network_interface.main` en el RG/región de `foundation` (`var.resource_group_name`, `var.location`), nombrada con `var.nic_name` y con `var.tags`
  - `ip_configuration` con `subnet_id = var.subnet_id`, `public_ip_address_id = var.public_ip_id` y `private_ip_address_allocation = "Dynamic"`; sin asociación de NSG
  - Observable: `terraform plan` muestra la creación de una NIC asociada a la subred y a la IP pública provistas por `networking`
  - _Requirements: 1.3, 2.1, 2.2, 2.3, 2.4_
  - _Boundary: azurerm_network_interface.main_
- [x] 2.2 Crear la aceptación condicional de términos Marketplace
  - Declarar `azurerm_marketplace_agreement.main` con `count = var.accept_marketplace_terms ? 1 : 0`, `publisher = var.image_publisher`, `offer = var.image_offer`, `plan = coalesce(var.image_plan_name, var.image_sku)`
  - Con el default `accept_marketplace_terms = false` el recurso no se crea (no-op) para la imagen HPC sin plan; con `true` acepta los términos de forma idempotente
  - Observable: con default, `terraform plan` no planifica el agreement (count 0); con `accept_marketplace_terms = true`, planifica exactamente un agreement
  - _Requirements: 3.1, 3.2_
  - _Boundary: azurerm_marketplace_agreement.main_
- [x] 2.3 Crear la máquina virtual GPU Linux
  - Declarar `azurerm_linux_virtual_machine.main` con `size = var.vm_size`, `source_image_reference` (4 campos por variable), `os_disk` (caching `ReadWrite`, `storage_account_type` y `disk_size_gb` por variable), nombrada con `var.vm_name` y con `var.tags`
  - Asociar la NIC (`network_interface_ids = [azurerm_network_interface.main.id]`); `admin_username = var.admin_username`; `admin_ssh_key` con `public_key = file(var.ssh_public_key_path)`; `disable_password_authentication = true`
  - Tipo de seguridad Standard: omitir `secure_boot_enabled`/`vtpm_enabled`; `depends_on = [azurerm_marketplace_agreement.main]` para ordenar términos → VM incluso con count 0
  - Observable: `terraform plan` muestra la creación de la VM con la NIC asociada, disco OS por variable, autenticación solo por llave SSH y sin argumentos de Trusted Launch
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.1, 5.2, 5.3_
  - _Depends: 2.1, 2.2_
  - _Boundary: azurerm_linux_virtual_machine.main_

- [ ] 3. Contratos de salida y plantilla de variables
- [x] 3.1 (P) Exponer los outputs para la Ola 4
  - Declarar en `outputs.tf` los outputs `snake_case`: `vm_name` (`azurerm_linux_virtual_machine.main.name`), `vm_public_ip` (`var.public_ip_address`) y `admin_username` (`var.admin_username`), con `description` descriptiva
  - No exponer información sensible (sin llave privada ni credenciales)
  - Observable: tras un `apply`, `terraform output` devuelve `vm_name`, `vm_public_ip` y `admin_username` con valores no sensibles
  - _Requirements: 6.1, 6.2, 6.3_
  - _Depends: 2.3_
  - _Boundary: outputs.tf_
- [x] 3.2 (P) Crear la plantilla `terraform.tfvars.example` versionada
  - Documentar todas las variables de entrada con placeholders (sin valores reales), siguiendo el estilo de `02-networking/terraform.tfvars.example`: comandos `terraform -chdir=../0X output -raw ...` para las dependencias, nota de fallback `ARM_*`, y ruta de llave SSH de ejemplo
  - Documentar como precondición que la feature `UseStandardSecurityType` debe estar registrada por `foundation`, y que `accept_marketplace_terms` se deja en `false` para `ubuntu-hpc` (activarlo solo para imágenes con plan, ajustando `image_plan_name` si difiere del SKU)
  - Verificar que el `.gitignore` existente excluye `*.tfvars` (salvo `.example`), `*.tfstate*`, `.terraform/` y `*.pem`/`*.pub`, manteniendo el código separado de los valores
  - Observable: `terraform.tfvars.example` está versionado con todas las variables documentadas y sin valores reales; `git status` no muestra ningún `terraform.tfvars` como candidato a commit
  - _Requirements: 7.3, 7.4, 8.4_
  - _Depends: 1.2_
  - _Boundary: terraform.tfvars.example, .gitignore_

- [x] 4. Validación estructural e idempotencia
- [x] 4.1 Verificar formato, validación e idempotencia de la capa
  - Ejecutar `terraform fmt -check` y `terraform validate` en `terraform/03-compute/` sin errores
  - Confirmar que un `terraform plan` con dependencias reales de `01`/`02` planifica NIC + VM (y agreement solo si aplica), y que tras un `apply` un `plan` inmediato reporta 0 add / 0 change / 0 destroy
  - Confirmar reconciliación: si un recurso gestionado deja de existir en Azure, el siguiente `apply` lo recrea sin intervención manual
  - Observable: `terraform fmt -check` y `terraform validate` salen con código 0; el `plan` posterior al `apply` reporta cero cambios
  - _Requirements: 8.1, 8.2, 8.3_
  - _Depends: 2.1, 2.2, 2.3, 3.1_

## Implementation Notes
- Tarea 4.1: validación estática (`fmt`/`validate`/`plan` con variables dummy) completada previamente, con Req 8.2 100% verificado. La validación manual con `apply` real (`terraform/03-compute/`, VM GPU H100 desplegada) se ejecutó el 2026-07-07 — ver `Resultado_Validacion_Manual_compute.md`. Veredicto: Req 8.1 (idempotencia post-apply) PASS, Req 8.3 (reconciliación) PASS y Req 6 (outputs) PASS — Decisión GO. Nota sobre Req 8.3: la evidencia es ambigua (el intento de borrar la NIC en el Paso 6a se hizo con la VM aún encendida, y Azure no permite borrar una NIC adjunta a una VM en ejecución, por lo que el "No changes" del plan posterior podría deberse a que la NIC nunca llegó a borrarse en vez de a una reconciliación real de Terraform). Aceptado como PASS por decisión explícita del usuario sin re-ejecutar la prueba con la VM desasociada/apagada.
- Se detectó (fuera del alcance de `compute`) que `terraform/02-networking` está aplicado pero sus outputs (`subnet_id`, `public_ip_id`, `public_ip_address`, `nsg_id`) no están escritos en el state — un `terraform plan -refresh-only` en esa capa muestra que se agregarían sin cambiar infraestructura. El operador deberá aplicar ese refresh (o un apply normal) en `02-networking` antes de poder obtener esos outputs reales para alimentar `03-compute`.
