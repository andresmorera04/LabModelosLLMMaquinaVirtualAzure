# Roadmap de Desarrollo — Estrategia por Capa de Infraestructura (Bottom-Up)

Descomposición del proyecto en 5 specs de Kiro, cada uno correspondiente a una capa técnica independiente. Cada spec es testeable de forma aislada y se integra progresivamente con las capas anteriores.

## Visión general

```
Ola 1: foundation ─────────────────────────────────────────────┐
Ola 2: networking ──────────────────────────────────────────┐   │
Ola 3: compute ──────────────────────────────────────────┐  │   │
Ola 4: vm-config ────────────────────────────────────┐   │  │   │
Ola 5: teardown-docs ────────────────────────────┐   │   │  │   │
                                                 ▼   ▼   ▼  ▼   ▼
                                              [Proyecto completo]
```

---

## Ola 1 — `foundation`

**Objetivo**: Establecer la base del despliegue en Azure: grupo de recursos y registro de features/providers necesarios.

**Alcance**:
- Directorio `terraform/01-foundation/`
- Configuración del provider `azurerm` con autenticación remota (no Azure CLI local del servidor)
- Creación idempotente del grupo de recursos `grre_desarrollo_lab` en East US 2
- Registro idempotente de la feature `UseStandardSecurityType` del namespace `Microsoft.Compute` (para evitar Trusted Launch)
- Re-registro del provider `Microsoft.Compute` tras activar la feature
- Archivos: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `terraform.tfvars.example`
- Output exportado: `resource_group_name`, `resource_group_id`, `location`

**Criterio de verificación**: `terraform plan` no muestra cambios tras un `apply` exitoso (idempotencia). El grupo de recursos existe en Azure. La feature `UseStandardSecurityType` está en estado `Registered`.

**Dependencias**: Ninguna.

---

## Ola 2 — `networking`

**Objetivo**: Crear la capa de red y seguridad que protege y conecta la VM.

**Alcance**:
- Directorio `terraform/02-networking/`
- Creación de VNet y Subnet para la VM
- Creación de IP pública estática (Standard SKU)
- Creación del Network Security Group (NSG) con reglas:
  - SSH (puerto 22) restringido a `MY_IP`
  - Ollama (puerto 11434) restringido a `MY_IP`
- Variable `my_ip` como input obligatorio, propagada a las reglas NSG
- Consumo de outputs de la Ola 1 (resource group name, location)
- Archivos: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `terraform.tfvars.example`
- Outputs exportados: `vnet_id`, `subnet_id`, `nsg_id`, `public_ip_id`, `public_ip_address`

**Criterio de verificación**: `terraform plan` idempotente. Las reglas NSG solo permiten tráfico desde `MY_IP` en los puertos 22 y 11434. La IP pública está asignada y es estática.

**Dependencias**: Ola 1 (`foundation`).

---

## Ola 3 — `compute`

**Objetivo**: Desplegar la VM GPU con acceso SSH funcional.

**Alcance**:
- Directorio `terraform/03-compute/`
- Creación de la NIC asociada a la Subnet y la IP pública de la Ola 2
- Aceptación idempotente de los términos de la imagen Marketplace `microsoft-dsvm:ubuntu-hpc:2404:latest`
- Creación de la VM `Standard_NC40ads_H100_v5` con:
  - Imagen HPC Ubuntu 24.04 (drivers NVIDIA preinstalados)
  - Disco OS Standard SSD 64 GB
  - Security type `Standard` (no Trusted Launch)
  - Llave SSH pública en formato PEM (referencia al archivo `.pem.pub`)
- Consumo de outputs de Ola 1 y Ola 2
- Archivos: `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `terraform.tfvars.example`
- Outputs exportados: `vm_id`, `vm_name`, `vm_public_ip`, `admin_username`, `ssh_command`

**Criterio de verificación**: `terraform plan` idempotente. La VM existe, está en estado `Running`, y es accesible por SSH desde la IP del desarrollador usando el archivo `.pem`. `nvidia-smi` dentro de la VM muestra 1x H100 NVL 94 GB.

**Dependencias**: Ola 1 (`foundation`), Ola 2 (`networking`).

---

## Ola 4 — `vm-config`

**Objetivo**: Configurar el entorno dentro de la VM para servir modelos LLM con Ollama.

**Alcance**:
- Directorio `scripts/`
- `01-montar-nvme.sh` — Detecta discos NVMe locales efímeros, los formatea (XFS) y monta en `/mnt/ollama`. Crea el servicio systemd `setup-ephemeral-ollama.service` para remontaje automático en cada arranque. Idempotente: verifica con `mountpoint -q`.
- `02-instalar-ollama.sh` — Instala Ollama si no existe (`command -v ollama`). Inicia el servicio de montaje NVMe si no está activo. Verifica versión instalada.
- `03-configurar-ollama.sh` — Crea el drop-in de systemd con las variables de entorno: `OLLAMA_HOST=0.0.0.0:11434`, `OLLAMA_ORIGINS=*`, `OLLAMA_MODELS=/mnt/ollama/models`, `OLLAMA_CONTEXT_LENGTH=262144`, `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`, `OLLAMA_KEEP_ALIVE=30m`. Reinicia el servicio. Idempotente: compara configuración existente antes de reescribir.
- `04-descargar-modelos.sh` — Descarga los 3 modelos definidos (`qwen3:30b-a3b-thinking-2507-q8_0`, `gemma4:31b-it-q8_0`, `qwen3-coder-next:q4_K_M`). Idempotente: verifica con `ollama list | grep` antes de cada pull.
- Todos los scripts: `set -euo pipefail`, compatibles con shellcheck.

**Criterio de verificación**: Cada script se puede ejecutar dos veces consecutivas sin error ni efecto secundario. `ollama ps` muestra el modelo corriendo en GPU. `curl http://localhost:11434/api/chat` responde correctamente. `nvidia-smi` muestra uso de VRAM.

**Dependencias**: Ola 3 (`compute`) — requiere VM accesible por SSH.

---

## Ola 5 — `teardown-docs`

**Objetivo**: Proveer destrucción controlada del laboratorio y documentación completa del proyecto.

**Alcance**:
- `scripts/destroy-lab.sh` — Script orquestador de ejecución exclusivamente manual que:
  - Ejecuta `terraform destroy` en orden inverso: `03-compute/` → `02-networking/` → `01-foundation/`
  - Cada paso es idempotente: si el recurso ya no existe, no falla
  - Pide confirmación explícita del usuario antes de proceder
  - Muestra un resumen de lo que se va a destruir antes de actuar
  - Nunca se ejecuta en pipelines automatizados
- `README.md` — Documentación completa del proyecto:
  - Descripción del proyecto y arquitectura
  - Prerrequisitos (Terraform, Azure CLI, SSH)
  - Instrucciones de despliegue por capas (con orden)
  - Instrucciones de configuración de la VM (scripts en orden)
  - Operación diaria (encender/apagar)
  - Instrucciones de destrucción
  - Estructura del repositorio
  - Costos estimados

**Criterio de verificación**: `destroy-lab.sh` ejecutado sobre un laboratorio desplegado elimina todos los recursos sin error. Ejecutado dos veces, la segunda no falla. El `README.md` permite a un nuevo desarrollador desplegar el laboratorio completo desde cero.

**Dependencias**: Ola 1 (`foundation`) para destrucción. Todas las olas para documentación.

---

## Orden de ejecución

```
Ola 1 (foundation) → Ola 2 (networking) → Ola 3 (compute) → Ola 4 (vm-config) → Ola 5 (teardown-docs)
```

Cada ola se ejecuta como un spec de Kiro independiente: `/kiro-spec-quick <nombre-del-spec>`.

## Referencia

- Guía base: `guia-vm-ollama-nc40ads-h100.md`
- Steering: `.kiro/steering/product.md`, `tech.md`, `structure.md`
