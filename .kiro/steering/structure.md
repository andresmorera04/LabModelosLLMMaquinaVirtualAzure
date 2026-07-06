# Estructura del Proyecto

## Filosofía de Organización

Organización por capas de responsabilidad, separando infraestructura (Terraform) de configuración (Bash), con cada capa de Terraform como directorio independiente con su propio state file. Los scripts Bash siguen un orden secuencial numérico. La documentación vive en la raíz del repositorio.

## Patrones de Directorio

### Infraestructura Terraform — por capas
**Ubicación**: `terraform/`
**Propósito**: Cada subdirectorio representa una capa de infraestructura con su propio `main.tf`, `variables.tf`, `outputs.tf` y state.
**Patrón**:
```
terraform/
  01-foundation/       # Grupo de recursos, registro de features/providers
  02-networking/       # VNet, Subnet, NSG, IP pública, reglas de seguridad
  03-compute/          # VM GPU, disco OS, NIC, llave SSH
```
Cada capa consume outputs de las anteriores vía `terraform_remote_state` o variables pasadas manualmente.

### Destrucción controlada del laboratorio
**Ubicación**: `scripts/destroy-lab.sh`
**Propósito**: Script orquestador de ejecución exclusivamente manual que destruye todos los recursos en orden inverso de dependencia.
**Patrón**: invoca `terraform destroy` secuencialmente: `03-compute/` → `02-networking/` → `01-foundation/`. Cada paso es idempotente (si el recurso ya no existe, no falla). Nunca se ejecuta en pipelines automatizados.

### Scripts de configuración de la VM
**Ubicación**: `scripts/`
**Propósito**: Scripts Bash idempotentes ejecutados dentro de la VM vía SSH, en orden numérico.
**Patrón**:
```
scripts/
  01-montar-nvme.sh        # Detecta y monta NVMe efímero en /mnt/ollama
  02-instalar-ollama.sh    # Instala Ollama si no existe
  03-configurar-ollama.sh  # Drop-in systemd, variables de entorno
  04-descargar-modelos.sh  # Pull de los modelos LLM definidos
```

### Documentación
**Ubicación**: raíz del repositorio
**Propósito**: README.md como punto de entrada, guía original como referencia.
**Patrón**:
- `README.md` — documentación principal del proyecto, se actualiza al completar cada spec
- `guia-vm-ollama-nc40ads-h100.md` — guía manual original de referencia (source of truth del "qué")

### Archivos de variables y configuración
**Ubicación**: raíz de cada capa Terraform
**Propósito**: Separar valores del código declarativo.
**Patrón**:
- `variables.tf` — declaración con tipo, descripción y defaults
- `terraform.tfvars` — valores específicos del despliegue (excluido de git)
- `terraform.tfvars.example` — plantilla con valores de ejemplo (incluida en git)

## Convenciones de Nombrado

- **Directorios Terraform**: `NN-kebab-case/` con número de capa
- **Scripts Bash**: `NN-kebab-case.sh` con número de secuencia
- **Archivos Terraform**: `kebab-case.tf` (main.tf, variables.tf, outputs.tf, providers.tf, data.tf)
- **Variables Terraform**: `snake_case` (e.g., `resource_group_name`, `vm_size`, `my_ip`)
- **Recursos Azure**: `prefijo-funcion` (e.g., `vm-ollama-h100`, `vm-ollama-h100-pip`)
- **Outputs Terraform**: `snake_case` descriptivo (e.g., `vm_public_ip`, `resource_group_id`)

## Principios de Organización del Código

- Cada capa de Terraform es desplegable independientemente y tiene un ciclo de vida propio.
- Los scripts Bash son autocontenidos: cada uno valida precondiciones y es re-ejecutable.
- Los archivos `.tfvars` con valores reales nunca se commitean; solo las plantillas `.tfvars.example`.
- El `.gitignore` incluye: `*.tfstate`, `*.tfstate.backup`, `.terraform/`, `*.tfvars` (excepto `.example`), `*.pem`.

---
_Documenta patrones, no árboles de archivos. Archivos nuevos que sigan estos patrones no requieren actualizar este documento_
