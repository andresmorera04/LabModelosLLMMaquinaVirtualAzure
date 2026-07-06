# Plan de Implementación

- [x] 1. Scaffolding del directorio y declaración de variables de entrada
  - Crear el directorio `terraform/01-foundation/`
  - Crear `variables.tf` con las 7 variables: `subscription_id`, `client_id`, `client_secret`, `tenant_id`, `resource_group_name`, `location`, `tags`
  - Cada variable con tipo explícito (`string`, `map(string)`) y descripción en español
  - Variables de autenticación (`client_id`, `client_secret`, `tenant_id`) con `sensitive = true` y `default = null`
  - Variables `location` (default `"eastus2"`) y `tags` (default `{}`) con defaults seguros y no sensibles
  - Variables `subscription_id` y `resource_group_name` sin default (obligatorias)
  - Verificar que `.gitignore` incluye exclusiones para Terraform: `*.tfstate`, `*.tfstate.backup`, `.terraform/`, `*.tfvars` (excepto `*.tfvars.example`)
  - Observable: el directorio `terraform/01-foundation/` existe; `terraform fmt -check variables.tf` no reporta diferencias; `.gitignore` contiene las exclusiones requeridas
  - _Requirements: 4.1, 4.2, 4.5_

- [ ] 2. Configuración del provider y recursos de infraestructura
- [x] 2.1 Configurar el provider azurerm con autenticación no interactiva
  - Crear `providers.tf` con bloque `terraform` que declare `required_version = ">= 1.5"` y `required_providers` con `hashicorp/azurerm >= 4.0`
  - Configurar bloque `provider "azurerm"` con `features {}`, credenciales desde variables (`var.subscription_id`, `var.client_id`, `var.client_secret`, `var.tenant_id`) y `resource_provider_registrations = "none"`
  - Variables con `default = null` permiten al provider caer a env vars `ARM_*` cuando no se proveen vía `.tfvars`
  - Observable: `terraform init` en `terraform/01-foundation/` descarga el provider azurerm exitosamente sin errores
  - _Requirements: 3.1, 3.2, 3.3_
  - _Boundary: ProviderConfig_

- [x] 2.2 Crear grupo de recursos y registro de feature UseStandardSecurityType (integración)
  - Crear `main.tf` con recurso `azurerm_resource_group.main` usando `var.resource_group_name`, `var.location` y `var.tags`
  - Crear recurso `azurerm_resource_provider_registration.compute` con `name = "Microsoft.Compute"` y bloque `feature` para `UseStandardSecurityType` con `registered = true`
  - Incluir `lifecycle { prevent_destroy = true }` en el recurso de registro del provider para proteger contra des-registro accidental durante `terraform destroy`
  - Tarea de integración: agrupa ResourceGroup y FeatureRegistration en `main.tf` porque comparten el mismo archivo y contexto de ejecución del provider
  - Observable: `terraform validate` pasa sin errores; `terraform plan` (con credenciales válidas e import previo del provider) muestra los recursos esperados
  - _Requirements: 1.1, 1.4, 2.1, 2.2_
  - _Boundary: ResourceGroup, FeatureRegistration_

- [ ] 3. Outputs y plantilla de variables
- [x] 3.1 Crear outputs para capas posteriores
  - Crear `outputs.tf` con 3 outputs: `resource_group_name`, `resource_group_id`, `location`
  - Cada output con descripción en español y valor referenciando atributos de `azurerm_resource_group.main`
  - Ningún output marcado como `sensitive`
  - Nombres de outputs en `snake_case` estables y descriptivos
  - Observable: `terraform plan` incluye los 3 outputs en la sección "Changes to Outputs"
  - _Requirements: 5.1, 5.2, 5.3_
  - _Boundary: Outputs_

- [x] 3.2 (P) Crear plantilla de variables de ejemplo
  - Crear `terraform.tfvars.example` con todas las variables declaradas en `variables.tf`
  - Usar valores placeholder claramente identificables (e.g., `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"` para UUIDs)
  - Incluir comentarios indicando cuáles variables pueden omitirse si se usan env vars `ARM_*`
  - No incluir secretos ni valores reales de ningún entorno
  - Observable: la plantilla lista todas las variables declaradas en `variables.tf` con placeholders; ningún valor es un secreto real
  - _Requirements: 4.3, 4.4_
  - _Boundary: VariablesTemplate_
  - _Depends: 1_

- [x] 4. Validación estructural de calidad
  - `terraform fmt -check` pasa sin diferencias de formato en todos los archivos `.tf` del directorio `01-foundation/`
  - `terraform validate` pasa sin errores
  - Verificar convenciones de nombrado del steering: archivos en `kebab-case.tf`, variables en `snake_case`, outputs en `snake_case`
  - Verificar separación de código y configuración: ningún valor de entorno hardcodeado en archivos `.tf`
  - Observable: `terraform fmt -check` y `terraform validate` pasan sin errores ni diferencias; todos los archivos y variables siguen las convenciones de nombrado
  - _Requirements: 6.2, 6.4_

- [x] 5. Validación de runtime, idempotencia y manejo de errores
  - Prerequisito de import: ejecutar `terraform import azurerm_resource_provider_registration.compute /subscriptions/<subscription-id>/providers/Microsoft.Compute` antes del primer apply si `Microsoft.Compute` ya está registrado en la suscripción
  - Verificar que `terraform plan` post-import muestra los recursos esperados con la feature `UseStandardSecurityType`
  - Verificar idempotencia: tras `terraform apply` exitoso, `terraform plan` inmediato reporta 0 cambios (`0 to add, 0 to change, 0 to destroy`)
  - Verificar reconciliación: si el grupo de recursos se elimina externamente (`az group delete`), el siguiente `terraform apply` lo recrea sin intervención manual
  - Verificar manejo de credenciales faltantes: `terraform plan` sin `.tfvars` ni env vars `ARM_*` falla con un mensaje que identifica el valor faltante, sin crear recursos parciales
  - Observable: `terraform plan` post-apply reporta `No changes. Infrastructure is up-to-date.`; la ejecución sin credenciales falla con error claro antes de cualquier operación sobre recursos
  - _Requirements: 6.1, 6.3, 1.2, 1.3, 2.3, 2.4, 3.3, 4.5_

## Implementation Notes

- El entorno de ejecución de los agentes no tiene Azure CLI ni variables `ARM_*`, por lo que `terraform import`, `terraform apply`, la verificación de idempotencia post-apply y la verificación de reconciliación (`az group delete` + apply) no pudieron ejecutarse contra Azure real durante la implementación. Quedan pendientes de verificación manual por el desarrollador con credenciales reales antes de dar la capa por operativa end-to-end. Lo que sí se verificó mecánicamente: `terraform fmt`, `terraform validate`, y el manejo de credenciales faltantes (`terraform plan` sin variables falla limpiamente antes de cualquier operación sobre recursos, sin state parcial).
- **Verificación manual completada** (ver `.kiro/specs/foundation/Resultados_Pruebas_Foundation.md`): el desarrollador ejecutó el flujo completo contra Azure real (suscripción `3e9dda65-6318-441d-9cd1-323be07d7a58`) usando autenticación por Service Principal. Resultados: (1) `terraform plan` sin credenciales falló limpiamente identificando `subscription_id`/`resource_group_name`, sin state parcial (Req 3.3, 4.5); (2) `Microsoft.Compute` ya estaba `Registered`, se importó exitosamente con `terraform import` (Req 2.1, 2.2); (3) `terraform apply` inicial creó `rg-llm-lab-ejemplo1` sin tocar la feature ya registrada (Req 1.1, 2.1, 2.2); (4) `terraform plan` post-apply reportó `No changes. Your infrastructure matches the configuration.` (Req 1.2, 2.3, 6.1 — idempotencia confirmada); (5) tags aplicadas coinciden exactamente vía `az group show` (Req 1.4); (6) tras `az group delete` externo, `terraform plan` detectó el drift (`Objects have changed outside of Terraform`) y `terraform apply` recreó el grupo de recursos sin intervención manual adicional ni reimport (Req 1.3, 6.3 — reconciliación confirmada); (7) limpieza final con `terraform destroy -target=azurerm_resource_group.main` funcionó como documentado, sin afectar el registro del provider (`prevent_destroy` intacto). Los 9 ítems del checklist de `guia_pruebas_foundation.md` quedaron en PASS.
