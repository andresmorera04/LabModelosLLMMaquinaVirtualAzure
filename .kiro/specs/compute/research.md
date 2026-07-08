# Registro de Investigación y Decisiones de Diseño — `compute`

---
**Propósito**: Capturar hallazgos de descubrimiento, investigaciones arquitectónicas y justificaciones que informan el diseño técnico de la capa `compute` (Ola 3, `terraform/03-compute/`).
---

## Summary
- **Feature**: `compute`
- **Discovery Scope**: Extension (integración con capas Terraform previas `01-foundation` y `02-networking`)
- **Key Findings**:
  - Las capas previas **no** usan `terraform_remote_state`; propagan los outputs entre capas como **variables de entrada manuales** con `validation` y mensajes de error que instruyen ejecutar `terraform -chdir=../0X output -raw <name>`. `compute` debe seguir el mismo patrón para consumir `foundation` (RG, región) y `networking` (subnet_id, public_ip_id, public_ip_address).
  - En `azurerm_linux_virtual_machine` el tipo de seguridad **Standard** no es un argumento explícito: se obtiene **omitiendo** `secure_boot_enabled`/`vtpm_enabled` (Trusted Launch es opt-in). El prerequisito a nivel de suscripción (feature `UseStandardSecurityType`) ya lo registra `01-foundation`, por lo que `compute` solo lo consume implícitamente.
  - La imagen `microsoft-dsvm:ubuntu-hpc:2404` suele ser gratuita y sin *plan* de Marketplace; declarar `azurerm_marketplace_agreement` de forma incondicional puede provocar un error de apply. Se resuelve con un recurso controlado por `count` (variable booleana), satisfaciendo REQ 3 de forma idempotente y sin romper cuando la imagen no requiere términos.

## Research Log

### Patrón de consumo entre capas Terraform
- **Context**: REQ 1 exige consumir RG/región de `foundation` y subnet_id/public_ip_id de `networking` sin redeclarar recursos.
- **Sources Consulted**: `terraform/01-foundation/{outputs.tf,variables.tf}`, `terraform/02-networking/{main.tf,outputs.tf,variables.tf,providers.tf,terraform.tfvars.example}`, steering `structure.md` (líneas 9-19), `tech.md`.
- **Findings**:
  - `02-networking` recibe `resource_group_name` y `location` como variables (no vía remote state). `resource_group_name` lleva `validation` con `length(trimspace(...)) > 0` y `error_message` que apunta a `terraform -chdir=../01-foundation output -raw resource_group_name`.
  - `01-foundation` expone `resource_group_name`, `resource_group_id`, `location`. `02-networking` expone `subnet_id`, `public_ip_id`, `public_ip_address`, `nsg_id`.
  - `providers.tf` es idéntico en ambas capas: `required_version >= 1.5`, `azurerm >= 4.0`, `resource_provider_registrations = "none"`, auth por variables `subscription_id/client_id/client_secret/tenant_id` con defaults `null` (fallback a `ARM_*`).
- **Implications**: `compute` copia el bloque `providers.tf` y el bloque de variables de autenticación tal cual. Consume `foundation`/`networking` como variables `resource_group_name`, `location`, `subnet_id`, `public_ip_id`, `public_ip_address`, cada una con `validation` no vacía y `error_message` que apunta al comando `terraform -chdir=../0X output -raw ...` correspondiente. REQ 1.4 se satisface porque una variable requerida vacía/faltante detiene el apply antes de crear recursos.

### Contrato de la VM GPU y disco (guía original)
- **Context**: REQ 4 define la VM con tamaño, imagen, disco y tipo de seguridad provistos por variables.
- **Sources Consulted**: `guia-vm-ollama-nc40ads-h100.md` (líneas 45-47, 92-118, 179-212), `.kiro/steering/tech.md`.
- **Findings**:
  - Tamaño: `Standard_NC40ads_H100_v5`. Imagen URN: `microsoft-dsvm:ubuntu-hpc:2404:latest` → `publisher=microsoft-dsvm`, `offer=ubuntu-hpc`, `sku=2404`, `version=latest`.
  - Disco OS: `StandardSSD_LRS`, 64 GB. Usuario admin: `azureuser`. Acceso solo por llave SSH pública (`--ssh-key-values *.pub`, sin password).
  - La guía usa Azure CLI con `--security-type Standard`; el equivalente Terraform es `azurerm_linux_virtual_machine` sin `secure_boot_enabled`/`vtpm_enabled`.
- **Implications**: Se usa `azurerm_linux_virtual_machine` con `source_image_reference` (4 campos por variable), `os_disk` (caching `ReadWrite`, `storage_account_type` y `disk_size_gb` por variable), `admin_ssh_key` con `public_key = file(var.ssh_public_key_path)`, `disable_password_authentication = true`. El NSG ya lo asocia `networking` a la subred (`--nsg-rule NONE` en la guía equivale a no asociar NSG a la NIC en `compute`).

### Tipo de seguridad Standard vs Trusted Launch en azurerm
- **Context**: REQ 4.7 exige tipo de seguridad `Standard`, dependiente de la feature `UseStandardSecurityType` de `foundation`.
- **Sources Consulted**: `terraform/01-foundation/main.tf` (recurso `azurerm_resource_provider_registration.compute` con feature `UseStandardSecurityType` y `prevent_destroy`), documentación azurerm_linux_virtual_machine (conocimiento del provider 4.x).
- **Findings**: El recurso `azurerm_linux_virtual_machine` no expone `security_type`. Trusted Launch se activa explícitamente con `secure_boot_enabled = true` y/o `vtpm_enabled = true`. Omitir ambos deja la VM en tipo Standard. La imagen HPC es Gen2; el registro de la feature a nivel de suscripción habilita la creación Standard sobre esa imagen.
- **Implications**: `compute` **no** declara `secure_boot_enabled` ni `vtpm_enabled`. La dependencia con la feature es implícita (a nivel de suscripción, ya registrada por `foundation`); `compute` no la redeclara. Se documenta como precondición de despliegue y como Revalidation Trigger.

### Aceptación de términos de imagen Marketplace
- **Context**: REQ 3 exige aceptar términos del publisher/offer/SKU de forma idempotente y sin fallar si ya están aceptados.
- **Sources Consulted**: `guia-vm-ollama-nc40ads-h100.md` (líneas 179-185, la aceptación CLI cae con `||` si la imagen no requiere términos), recurso `azurerm_marketplace_agreement`.
- **Findings**:
  - `azurerm_marketplace_agreement` (args `publisher`, `offer`, `plan`) es idempotente por diseño: si el agreement ya existe, el apply no lo recrea.
  - Riesgo: si la imagen **no** tiene plan/términos (caso frecuente de `ubuntu-hpc`), declarar el recurso incondicionalmente produce un error de apply, contradiciendo la naturaleza "si aplica" de la guía.
- **Implications**: Se declara `azurerm_marketplace_agreement` con `count = var.accept_marketplace_terms ? 1 : 0`. La variable booleana (default alineado a REQ 3) permite habilitar la aceptación cuando la imagen la requiere y desactivarla cuando no, sin editar código. `plan` toma el valor de `var.image_sku`. Se documenta como riesgo con mitigación.

## Architecture Pattern Evaluation

| Opción | Descripción | Fortalezas | Riesgos / Limitaciones | Notas |
|--------|-------------|-----------|------------------------|-------|
| Variables manuales entre capas (elegida) | RG/región/IDs de red se pasan como variables con `validation` | Consistente con `01`/`02`; sin acoplamiento a rutas de state; capas independientes | El operador debe copiar outputs manualmente | Patrón vigente del proyecto (structure.md L19) |
| `terraform_remote_state` | `compute` lee el state de `01`/`02` como data source | Menos copiado manual | Acopla a la ubicación/backend del state; rompe independencia de capas; diverge del patrón existente | Rechazada por inconsistencia |
| Marketplace agreement incondicional | Recurso siempre presente | Más simple | Falla si la imagen no tiene términos | Rechazada por REQ 3.2 (no debe fallar) |
| Marketplace agreement con `count` (elegida) | Recurso gated por variable booleana | Idempotente; no falla en imágenes sin términos; parametrizado | Requiere que el operador conozca si la imagen tiene términos | Alineado a la lógica "si aplica" de la guía |

## Design Decisions

### Decision: Consumo de capas previas vía variables manuales validadas
- **Context**: REQ 1 (consumir foundation/networking sin redeclarar) y REQ 1.4 (fallar si la dependencia falta).
- **Alternatives Considered**:
  1. `terraform_remote_state` — data source que lee el state de capas previas.
  2. Variables de entrada manuales con `validation` (patrón vigente en `02-networking`).
- **Selected Approach**: Variables `resource_group_name`, `location`, `subnet_id`, `public_ip_id`, `public_ip_address` con `validation` que exige valor no vacío y `error_message` apuntando a `terraform -chdir=../01-foundation output ...` / `../02-networking output ...`.
- **Rationale**: Mantiene las capas desacopladas y desplegables de forma independiente (structure.md), reutiliza el patrón ya probado, y satisface REQ 1.4 de forma natural (variable requerida vacía detiene el apply).
- **Trade-offs**: Copiado manual de outputs a cambio de independencia y consistencia.
- **Follow-up**: Verificar en implementación que los mensajes de error citen el comando correcto por dependencia.

### Decision: Tipo de seguridad Standard por omisión de Trusted Launch
- **Context**: REQ 4.7.
- **Selected Approach**: No declarar `secure_boot_enabled`/`vtpm_enabled` en `azurerm_linux_virtual_machine`; depender de la feature `UseStandardSecurityType` ya registrada por `foundation`.
- **Rationale**: Es la forma canónica de obtener Standard en azurerm 4.x; evita redeclarar el registro de feature (fuera de boundary).
- **Trade-offs**: La dependencia con la feature es implícita; si `foundation` no la registró, el apply de la VM fallará (comportamiento aceptable: falla explícita antes de crear la VM).
- **Follow-up**: Documentar la precondición en la plantilla de variables y en el brief de tareas.

### Decision: Marketplace agreement condicional por `count`
- **Context**: REQ 3.1, 3.2.
- **Selected Approach**: `azurerm_marketplace_agreement` con `count = var.accept_marketplace_terms ? 1 : 0`, `plan = var.image_sku`.
- **Rationale**: Idempotente y tolerante a imágenes sin términos; parametrizable sin editar código (REQ 7).
- **Trade-offs**: Introduce una variable booleana adicional que el operador debe entender.
- **Follow-up**: Confirmar durante implementación si `ubuntu-hpc:2404` requiere términos; ajustar el default de la plantilla en consecuencia.

### Decision: Output de IP pública a partir de variable de entrada
- **Context**: REQ 6.1 exige exponer la IP pública, pero `compute` no crea la IP (la crea `networking`).
- **Alternatives Considered**:
  1. `data "azurerm_public_ip"` para leer la dirección por nombre/RG.
  2. Recibir `public_ip_address` como variable desde el output de `networking` y re-exponerla.
- **Selected Approach**: Variable `public_ip_address` (con `validation`) re-expuesta como output.
- **Rationale**: Consistente con el patrón de variables manuales; evita un data source y permisos extra; la IP es estática (asignación `Static` en `networking`), por lo que el valor es estable.
- **Trade-offs**: Un valor más que copiar; a cambio, cero acoplamiento adicional.
- **Follow-up**: Ninguno.

## Risks & Mitigations
- **La imagen no requiere términos y el agreement falla** — Mitigación: recurso gated por `count`/variable booleana; default documentado en la plantilla.
- **Feature `UseStandardSecurityType` no registrada en la suscripción** — Mitigación: es responsabilidad de `foundation`; documentar como precondición; la creación Standard fallará de forma explícita antes de crear la VM (sin recursos parciales de la VM).
- **`ssh_public_key_path` inválida o ilegible** — Mitigación: `validation` con `fileexists(...)` y uso de `file(...)`; ambos detienen el apply con error claro antes de crear la VM (REQ 5.4).
- **Deriva de la IP pública si `networking` se recrea** — Mitigación: la IP es `Static`; documentar que un cambio en `networking` (Revalidation Trigger) obliga a re-copiar `public_ip_id`/`public_ip_address`.

## References
- `guia-vm-ollama-nc40ads-h100.md` — fuente del "qué": URN de imagen, tamaño, disco, usuario, flujo de creación.
- `terraform/02-networking/` — patrón de referencia para providers, variables validadas, outputs y plantilla `.tfvars.example`.
- `.kiro/steering/{tech.md,structure.md,product.md}` — estándares de nombrado, idempotencia y organización por capas.
