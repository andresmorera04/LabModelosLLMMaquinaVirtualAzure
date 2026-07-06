# Investigación y Decisiones de Diseño — foundation

## Resumen
- **Feature**: `foundation`
- **Alcance del descubrimiento**: New Feature (greenfield, complejidad baja)
- **Hallazgos clave**:
  - Los recursos nativos del provider azurerm cubren todos los requisitos sin necesidad de provisioners ni módulos externos
  - El recurso `azurerm_resource_provider_registration` con bloque `feature` gestiona registro de feature + provider en un solo recurso idempotente
  - La autenticación flexible (variables con default null + fallback a env vars ARM_*) satisface el requisito de credenciales vía variables o entorno

## Registro de investigación

### Recurso Terraform para registro de features de Azure
- **Contexto**: El requisito 2 requiere registrar la feature `UseStandardSecurityType` de `Microsoft.Compute` de forma idempotente
- **Fuentes consultadas**: Documentación del provider azurerm en Terraform Registry, guía original del proyecto (`guia-vm-ollama-nc40ads-h100.md`), issues de GitHub del provider
- **Hallazgos**:
  - `azurerm_resource_provider_registration` acepta un bloque `feature` con atributos `name` y `registered`
  - Al establecer `registered = true`, Terraform registra la feature y espera internamente (timeout por defecto de 2 horas)
  - Solo features con `ApprovalType = "AutoApproval"` pueden gestionarse vía Terraform; `UseStandardSecurityType` cumple este criterio
  - Se requiere `resource_provider_registrations = "none"` en el bloque del provider para evitar conflictos con el auto-registro
  - **Hallazgo crítico**: El recurso **NO es idempotente** si el provider ya está registrado en la suscripción. Si `Microsoft.Compute` ya existe (caso habitual en cualquier suscripción activa), `terraform apply` falla con: *"A resource with the ID ... already exists - to be managed via Terraform this resource needs to be imported into the State."* Se requiere un paso de `terraform import` en la primera ejecución
  - Issue conocido [#31079](https://github.com/hashicorp/terraform-provider-azurerm/issues/31079): errores esporádicos de "inconsistent result after apply" en la lectura de estado
- **Implicaciones**: Un solo recurso cubre los requisitos 2.1, 2.2, 2.3 y 2.4 sin `null_resource` ni scripts auxiliares, pero requiere importar el provider en la primera ejecución si ya está registrado en Azure

### Autenticación del provider azurerm con variables opcionales
- **Contexto**: El requisito 3 requiere autenticación no interactiva vía variables de entrada o de entorno
- **Fuentes consultadas**: Documentación del provider azurerm (autenticación por Service Principal), documentación de Terraform sobre configuración de providers
- **Hallazgos**:
  - Las variables de Terraform con `default = null` se pasan al provider como "no definidas" (comportamiento documentado de Terraform: null = argumento omitido)
  - Cuando un argumento del provider es null/no definido, el provider cae a la variable de entorno correspondiente (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`)
  - En azurerm v4.x, `subscription_id` es requerido para operaciones `plan`/`apply` (no para `validate`); puede provenir del argumento del provider o de `ARM_SUBSCRIPTION_ID`. Se declara como variable obligatoria (sin default) por requisito explícito 3.2
  - Nota histórica: bug en v4.0.0 ([#27175](https://github.com/hashicorp/terraform-provider-azurerm/issues/27175)) donde el fallback a env var no funcionaba; corregido en v4.0.1+
  - Si no se provee ninguna credencial (ni variable ni env var), Terraform falla en `init`/`plan` con mensaje claro antes de crear recursos
- **Implicaciones**: Se logra autenticación flexible sin lógica condicional en HCL. El desarrollador elige si usa `.tfvars` o env vars `ARM_*`

### Configuración de `resource_provider_registrations` en el provider
- **Contexto**: El provider azurerm auto-registra ciertos resource providers por defecto, lo que puede conflictar con el recurso `azurerm_resource_provider_registration`
- **Fuentes consultadas**: Documentación del provider azurerm v4.x
- **Hallazgos**:
  - El argumento `resource_provider_registrations` acepta valores `"none"`, `"core"`, `"extended"`, `"all"`
  - Valor `"none"` desactiva todo auto-registro; el proyecto gestiona cada provider manualmente
  - Esto es requisito cuando se usa `azurerm_resource_provider_registration` para evitar conflictos de estado
- **Implicaciones**: Se establece `resource_provider_registrations = "none"` en el provider. Esta capa solo registra `Microsoft.Compute`; los demás providers que necesite el provider azurerm internamente ya están registrados por defecto en suscripciones Azure activas

## Evaluación de patrones de arquitectura

| Opción | Descripción | Fortalezas | Riesgos / Limitaciones | Notas |
|--------|-------------|-----------|------------------------|-------|
| Módulo plano | Archivos .tf directos en `01-foundation/`, sin submódulos | Simplicidad máxima, sin indirección | Ninguno para este alcance | Alineado con steering: cada capa es un directorio independiente |
| Módulo con submódulos | Separar grupo de recursos y feature en submódulos | Reutilización teórica | Sobre-ingeniería para 2 recursos; viola principio de simplificación | Descartado |
| Provisioners + null_resource | Usar `az feature register` vía local-exec | Familiaridad con la guía manual | No declarativo, no idempotente nativo, difícil de gestionar estado | Descartado por steering (Terraform declarativo sobre scripts imperativos) |

## Decisiones de diseño

### Decisión: Estado local de Terraform (no backend remoto)

- **Contexto**: Las capas posteriores necesitan consumir outputs de foundation
- **Alternativas consideradas**:
  1. Backend remoto en Azure Storage Account — requiere crear el storage account antes de foundation (chicken-and-egg)
  2. Estado local con consumo vía `terraform_remote_state` backend local
  3. Estado local con paso manual de valores como variables
- **Enfoque seleccionado**: Estado local. Las capas posteriores reciben los valores como variables de entrada
- **Justificación**: Evita la dependencia circular (no se puede crear el storage account sin un grupo de recursos, que es lo que esta capa crea). Mantiene la capa autocontenida
- **Compensaciones**: Los valores deben pasarse manualmente entre capas (o extraerse con `terraform output`). Para un laboratorio de un desarrollador, esto es aceptable
- **Seguimiento**: Si en el futuro se migra a backend remoto, solo se necesita agregar un bloque `backend` en `providers.tf` y migrar el estado con `terraform init -migrate-state`

### Decisión: Autenticación flexible con variables nullable

- **Contexto**: El requisito 3.1 pide autenticación "mediante variables de entrada o de entorno"
- **Alternativas consideradas**:
  1. Solo variables de Terraform (obligar `.tfvars` con credenciales)
  2. Solo variables de entorno (no declarar variables de auth en HCL)
  3. Variables con `default = null` (el provider usa env vars como fallback)
- **Enfoque seleccionado**: Opción 3 — variables con `default = null`
- **Justificación**: Cubre ambos escenarios del requisito sin lógica condicional. El usuario elige el mecanismo de su preferencia
- **Compensaciones**: `subscription_id` permanece obligatorio (sin default null) por requisito 3.2 explícito

### Decisión: No marcar `subscription_id` como sensitive

- **Contexto**: Determinar si el identificador de suscripción debe ocultarse en los logs de Terraform
- **Alternativas consideradas**:
  1. `sensitive = true` — oculta el valor en toda salida de Terraform
  2. `sensitive = false` — visible en plan/apply, útil para verificación
- **Enfoque seleccionado**: No marcarlo como sensitive
- **Justificación**: El subscription ID no es un secreto en el ecosistema Azure (aparece en URLs del portal, documentación de soporte). Marcarlo como sensitive dificulta la depuración sin aportar seguridad real. Las credenciales de autenticación (`client_id`, `client_secret`, `tenant_id`) sí se marcan como sensitive

## Resultados de síntesis

### Generalización
- Los 6 requisitos cubren aspectos ortogonales (grupo de recursos, features, autenticación, parametrización, outputs, calidad). No existe un problema subyacente común que generalizar
- Cada requisito se implementa con un componente o mecanismo distinto de Terraform

### Build vs Adopt
- Todos los componentes usan recursos nativos del provider azurerm — no se identificaron librerías, módulos de la comunidad ni herramientas externas necesarias
- El registro de features se resuelve nativamente con `azurerm_resource_provider_registration` sin necesidad de scripts CLI

### Simplificación
- Se eliminó la opción de submódulos por ser sobre-ingeniería para 2 recursos
- Se eliminó la opción de backend remoto por crear dependencia circular
- El diseño final usa 5 archivos planos y 3 recursos de Terraform — la implementación mínima que satisface todos los requisitos

## Riesgos y mitigaciones

- **Provider ya registrado en Azure (riesgo alto)**: `Microsoft.Compute` está registrado por defecto en suscripciones Azure activas. El primer `terraform apply` falla si no se importa el recurso al state. Mitigación: documentar paso de `terraform import` como prerequisito de primera ejecución. Comando: `terraform import azurerm_resource_provider_registration.compute /subscriptions/<subscription-id>/providers/Microsoft.Compute`
- **Propagación lenta de la feature**: El registro de `UseStandardSecurityType` puede tardar varios minutos (timeout de 2 horas). Mitigación: el provider azurerm espera internamente; se documenta en las notas de implementación
- **Errores esporádicos de estado**: Issue [#31079](https://github.com/hashicorp/terraform-provider-azurerm/issues/31079) reporta "inconsistent result after apply" intermitentes. Mitigación: re-ejecutar `terraform apply` si ocurre; es un error transitorio
- **Permisos insuficientes del Service Principal**: Si el SP no tiene rol Contributor o similar en la suscripción, el apply falla. Mitigación: documentar en `terraform.tfvars.example` los permisos requeridos
- **Conflicto de auto-registro de providers**: Si se omite `resource_provider_registrations = "none"`, el provider podría conflictar con el recurso manual. Mitigación: incluido como requisito explícito en el diseño

## Referencias
- [Documentación azurerm_resource_provider_registration](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_provider_registration) — recurso para registro de providers y features
- [Autenticación por Service Principal con Client Secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret) — guía de autenticación del provider
- [FAQ de Trusted Launch — UseStandardSecurityType](https://learn.microsoft.com/en-us/azure/virtual-machines/trusted-launch-faq) — documentación de la feature de Azure
- Guía base del proyecto: `guia-vm-ollama-nc40ads-h100.md` — Fases 3.1 y 3.2 documentan el proceso manual equivalente
