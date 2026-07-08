# Guía de Validación Manual — Spec `compute`

## Objetivo

Esta guía cubre las verificaciones que quedaron pendientes como **MANUAL_VERIFY_REQUIRED** en `/kiro-validate-impl compute`, porque requieren un `terraform apply` real contra Azure (creación de una VM GPU con costo) que no se ejecuta automáticamente:

- **Requirement 8.1**: un `terraform plan` inmediato después de un `apply` exitoso reporta cero cambios (idempotencia).
- **Requirement 8.3**: si un recurso gestionado deja de existir en Azure, el siguiente `apply` lo reconcilia (recrea) sin intervención manual.
- Prerrequisito operativo detectado durante la implementación: los outputs de `terraform/02-networking` (`subnet_id`, `public_ip_id`, `public_ip_address`, `nsg_id`) no están refrescados en su state; hay que aplicarlos antes de poder consumirlos en `compute`.

Cada paso de esta guía incluye el comando exacto a ejecutar y una instrucción para **anexar su salida** a un archivo de resultados versionable, de modo que quede evidencia concreta de la ejecución (no solo la afirmación de que "se corrió").

## ⚠️ Estado actual del laboratorio: todo fue destruido

**El laboratorio completo fue destruido.** Ningún recurso de las capas anteriores existe actualmente en Azure:

- `terraform/01-foundation` (resource group, etc.) — **destruido**.
- `terraform/02-networking` (VNet, subnet, NSG, IP pública) — **destruido**.

Esta guía **no puede asumir** que `01-foundation` y `02-networking` ya están aplicados. Antes de tocar `03-compute`, hay que **recrear desde cero** ambas capas previas, en orden (`01-foundation` → `02-networking` → `03-compute`), porque `compute` depende de sus outputs (`resource_group_name`, `location`, `subnet_id`, `public_ip_id`, `public_ip_address`).

Los `terraform.tfstate` locales de `01-foundation`/`02-networking` pueden contener referencias residuales a recursos que ya no existen en Azure (drift total). Antes de aplicar, revisa con `terraform plan` si el state necesita limpieza (`terraform state list` / `terraform state rm` para entradas obsoletas, o directamente reinicializar el state si está vacío de recursos reales) — no asumas que un `apply` normal alcanza si el state está inconsistente con la realidad.

El **Paso 1** de esta guía fue actualizado para reflejar esto: ya no es un simple "refresh-only" de outputs, sino un `apply` real de `01-foundation` y `02-networking` desde cero.

## Advertencia de costo — leer antes de continuar

El **Paso 4** de esta guía ejecuta un `terraform apply` real que crea una máquina virtual `Standard_NC40ads_H100_v5` (1x GPU NVIDIA H100 NVL 94 GB) en tu suscripción de Azure. Costo aproximado:

- **Encendida**: ~$6.98 USD/hora.
- **Apagada** (`az vm deallocate`): ~$9 USD/mes (disco + IP pública, sin cómputo).

No ejecutes el Paso 4 (ni el Paso 6 de reconciliación) hasta que estés listo para asumir ese costo. Los Pasos 0-3 y 5 son de solo lectura/planificación (`terraform plan`, `terraform output`) y no tienen costo ni crean recursos.

Al terminar tus pruebas, **apaga la VM** con `az vm deallocate` (ver Paso 7) para minimizar costo. La destrucción completa del laboratorio es responsabilidad de la capa `teardown-docs` (Ola 5, spec separado) — esta guía no la cubre.

## Prerrequisitos

- Terraform `>= 1.5` instalado (`terraform version`).
- Azure CLI autenticado con la suscripción correcta (`az account show`).
- Llave SSH pública generada (según `guia-vm-ollama-nc40ads-h100.md`): `~/.ssh/ollama_h100.pem` / `~/.ssh/ollama_h100.pem.pub`.
- `terraform/01-foundation/` y `terraform/02-networking/` **NO están aplicados actualmente** (el laboratorio fue destruido) — el Paso 1 de esta guía los recrea desde cero antes de continuar con `compute`.
- Las 8 tareas de `.kiro/specs/compute/tasks.md` marcadas `[x]` (verificación estática ya completada).

## Convención del archivo de resultados

Todos los pasos anexan su salida a un único archivo Markdown dentro de este spec:

```
.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

El archivo **no existe todavía** — el Paso 0 lo crea. Cada ejecución posterior de esta guía **anexa** una nueva sección con fecha/hora, para conservar el historial de corridas (no se sobrescribe). Cada comando de esta guía sigue el patrón:

```bash
{
  echo "### <Título del paso> — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  <comando real>
  echo '```'
  echo
} | tee -a .kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

Ejecuta todos los comandos desde la raíz del repositorio, salvo que se indique lo contrario.

---

## Paso 0 — Inicializar el archivo de resultados

```bash
RESULT_FILE=".kiro/specs/compute/Resultado_Validacion_Manual_compute.md"

{
  echo "# Resultado de Validación Manual — Spec \`compute\`"
  echo
  echo "Corrida iniciada: $(date '+%Y-%m-%d %H:%M:%S')"
  echo
} | tee -a "$RESULT_FILE"
```

## Paso 1 — Recrear `01-foundation` y `02-networking` desde cero

**El laboratorio fue destruido**: no hay recursos reales de `foundation` ni `networking` en Azure. Este paso reemplaza el refresh-only original — ahora hay que aplicar ambas capas completas antes de poder consumir sus outputs en `compute`.

Antes de aplicar, revisa que el state local no tenga referencias residuales inconsistentes con Azure (drift total tras la destrucción):

```bash
{
  echo "### Paso 1a: Verificación de state previo a reaplicar — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  echo '--- 01-foundation state ---'
  terraform -chdir=terraform/01-foundation state list
  echo '--- 02-networking state ---'
  terraform -chdir=terraform/02-networking state list
  echo '```'
  echo
} | tee -a .kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

Si aparecen entradas de recursos que ya no existen en Azure, límpialas (`terraform state rm <recurso>`) antes de continuar, para que el `plan` no intente operar sobre referencias muertas.

Aplica `01-foundation`:

```bash
cd terraform/01-foundation

{
  echo "### Paso 1b: terraform plan en 01-foundation (recreación completa) — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform init -upgrade=false
  terraform plan -var-file=terraform.tfvars -no-color
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

Revisa el plan — debe mostrar la creación de los recursos base (resource group, etc.), no cambios sobre recursos inexistentes. Si es correcto, aplícalo:

```bash
{
  echo "### Paso 1c: terraform apply en 01-foundation — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform apply -var-file=terraform.tfvars -auto-approve -no-color
  echo '```'
  echo "### Outputs resultantes de 01-foundation"
  echo '```'
  terraform output
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md

cd ../..
```

Aplica `02-networking` (depende de los outputs de `01-foundation`):

```bash
cd terraform/02-networking

{
  echo "### Paso 1d: terraform plan en 02-networking (recreación completa) — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform init -upgrade=false
  terraform plan -var-file=terraform.tfvars -no-color
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

Revisa el plan de la misma forma. Si es correcto, aplícalo:

```bash
{
  echo "### Paso 1e: terraform apply en 02-networking — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform apply -var-file=terraform.tfvars -auto-approve -no-color
  echo '```'
  echo "### Outputs resultantes de 02-networking"
  echo '```'
  terraform output
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md

cd ../..
```

**Criterio de éxito**: `terraform output` en `01-foundation` y `02-networking` devuelve valores no vacíos (`resource_group_name`, `location`, `subnet_id`, `public_ip_id`, `public_ip_address`, `nsg_id`), y ambos `apply` terminan sin error.

## Paso 2 — Crear `terraform.tfvars` real en `03-compute`

```bash
cd terraform/03-compute
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` (NO lo commitees — ya está excluido por `.gitignore`) y completa:

| Variable | Cómo obtenerla |
|----------|----------------|
| `subscription_id` | `az account show --query id -o tsv` |
| `resource_group_name` | `terraform -chdir=../01-foundation output -raw resource_group_name` |
| `location` | `terraform -chdir=../01-foundation output -raw location` |
| `subnet_id` | `terraform -chdir=../02-networking output -raw subnet_id` |
| `public_ip_id` | `terraform -chdir=../02-networking output -raw public_ip_id` |
| `public_ip_address` | `terraform -chdir=../02-networking output -raw public_ip_address` |
| `ssh_public_key_path` | Ruta real a tu llave pública, ej. `~/.ssh/ollama_h100.pem.pub` |

El resto de variables tiene defaults seguros (puedes omitirlas u override según necesites).

```bash
{
  echo "### Paso 2: Valores de dependencias capturados — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  echo "resource_group_name = $(terraform -chdir=../01-foundation output -raw resource_group_name)"
  echo "location            = $(terraform -chdir=../01-foundation output -raw location)"
  echo "subnet_id           = $(terraform -chdir=../02-networking output -raw subnet_id)"
  echo "public_ip_id        = $(terraform -chdir=../02-networking output -raw public_ip_id)"
  echo "public_ip_address   = $(terraform -chdir=../02-networking output -raw public_ip_address)"
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

## Paso 3 — Validación estructural y plan de creación

```bash
{
  echo "### Paso 3: fmt / validate / plan — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform init -upgrade=false
  echo '--- fmt -check ---'
  terraform fmt -check -diff -recursive
  echo '--- validate ---'
  terraform validate
  echo '--- plan ---'
  terraform plan -var-file=terraform.tfvars -no-color
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

**Criterio de éxito**: `fmt`/`validate` sin errores; el plan muestra la creación de la NIC y la VM (y el agreement solo si `accept_marketplace_terms = true`), sin errores de variables.

Revisa manualmente el plan antes de continuar al siguiente paso — este es el último punto antes de crear recursos reales con costo.

## Paso 4 — `apply` real (CREA LA VM, tiene costo) ⚠️

Ejecuta esto solo cuando hayas revisado el plan del Paso 3 y estés de acuerdo con crear la VM real.

```bash
{
  echo "### Paso 4: terraform apply real — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform apply -var-file=terraform.tfvars -no-color -auto-approve
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

## Paso 5 — Verificar Requirement 8.1 (idempotencia: plan inmediato con cero cambios)

```bash
{
  echo "### Paso 5: Plan inmediato post-apply (Requirement 8.1) — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform plan -var-file=terraform.tfvars -no-color
  echo '```'
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md

{
  echo
  echo "**Criterio Requirement 8.1**: la línea final debe ser \`No changes. Your infrastructure matches the configuration.\`"
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

Si el plan reporta cambios inesperados, márcalo como `FAIL` en el archivo de resultados junto con el diff reportado, y no continúes al Paso 6 sin investigar la causa.

## Paso 6 — Verificar Requirement 8.3 (reconciliación de un recurso eliminado) — opcional

Este paso borra deliberadamente la NIC creada por esta capa directamente en Azure (fuera de Terraform) para comprobar que el siguiente `apply` la reconcilia sin intervención manual. Es una prueba destructiva controlada sobre un recurso que Terraform va a recrear inmediatamente después.

```bash
NIC_NAME=$(terraform show -json | jq -r '.values.root_module.resources[] | select(.type=="azurerm_network_interface") | .values.name')
RG_NAME=$(terraform -chdir=../01-foundation output -raw resource_group_name)

{
  echo "### Paso 6a: Eliminar NIC manualmente para probar reconciliación — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  echo "Eliminando NIC: $NIC_NAME en RG: $RG_NAME"
  az network nic delete --resource-group "$RG_NAME" --name "$NIC_NAME"
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

> Nota: si Azure no permite borrar la NIC porque sigue asociada a la VM en ejecución, primero detén la VM (`az vm stop` o `az vm deallocate` con el nombre de la VM, obtenido de `terraform output vm_name`), borra la NIC, y luego continúa. Terraform recreará la NIC y volverá a asociarla a la VM existente en el siguiente `apply`.

```bash
{
  echo "### Paso 6b: terraform plan tras eliminar la NIC (debe detectar el drift) — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform plan -var-file=terraform.tfvars -no-color
  echo '```'
  echo "### Paso 6c: terraform apply para reconciliar (Requirement 8.3) — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform apply -var-file=terraform.tfvars -no-color -auto-approve
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

**Criterio Requirement 8.3**: el `plan` del Paso 6b detecta que la NIC falta y planea recrearla; el `apply` del Paso 6c la recrea exitosamente sin errores ni intervención manual adicional (más allá de correr `apply`).

## Paso 7 — Verificar outputs y apagar la VM

```bash
{
  echo "### Paso 7: Outputs finales — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  terraform output
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

**Criterio Requirement 6**: `vm_name`, `vm_public_ip`, `admin_username` presentes y sin datos sensibles.

Para minimizar el costo mientras no estés usando el laboratorio (sin destruir la infraestructura):

```bash
VM_NAME=$(terraform output -raw vm_name)
RG_NAME=$(terraform -chdir=../01-foundation output -raw resource_group_name)

{
  echo "### Paso 7b: Apagar la VM (az vm deallocate) — $(date '+%Y-%m-%d %H:%M:%S')"
  echo '```'
  az vm deallocate --resource-group "$RG_NAME" --name "$VM_NAME"
  echo '```'
  echo
} | tee -a ../../.kiro/specs/compute/Resultado_Validacion_Manual_compute.md

cd ../..
```

## Paso 8 — Cerrar el veredicto en el archivo de resultados

Anexa manualmente al final de `Resultado_Validacion_Manual_compute.md` un veredicto explícito, por ejemplo:

```bash
{
  echo "## Veredicto final de esta corrida — $(date '+%Y-%m-%d %H:%M:%S')"
  echo "- Requirement 8.1 (idempotencia post-apply): PASS | FAIL"
  echo "- Requirement 8.3 (reconciliación de recurso eliminado): PASS | FAIL | NO EJECUTADO"
  echo "- Requirement 6 (outputs correctos): PASS | FAIL"
  echo "- Decisión: GO | NO-GO"
  echo
} | tee -a .kiro/specs/compute/Resultado_Validacion_Manual_compute.md
```

Reemplaza `PASS | FAIL` por el resultado real observado en los pasos anteriores antes de guardar.

---

## Resumen de criterios por requisito

| Requisito | Paso que lo verifica | Criterio de éxito |
|-----------|----------------------|--------------------|
| 8.1 — Idempotencia | Paso 5 | `terraform plan` reporta `No changes` inmediatamente después del `apply` |
| 8.3 — Reconciliación | Paso 6 | Tras borrar la NIC en Azure, el siguiente `apply` la recrea sin error |
| 6.1–6.3 — Outputs | Paso 7 | `terraform output` devuelve `vm_name`, `vm_public_ip`, `admin_username` sin datos sensibles |
| Prerrequisito de dependencias | Paso 1 | `01-foundation` y `02-networking` recreados desde cero; `terraform output` devuelve valores no vacíos en ambos |
