# Stack Tecnológico

## Arquitectura

Arquitectura en dos fases separadas por contexto de ejecución:

1. **Fase de infraestructura (remota → Azure)**: Terraform ejecutado desde la máquina del desarrollador, organizado en capas por nivel de abstracción.
2. **Fase de configuración (dentro de la VM)**: scripts Bash numerados secuencialmente, ejecutados vía SSH dentro de la VM Ubuntu ya creada.

Esta separación existe porque Terraform gestiona infraestructura declarativa pero no es idóneo para tareas imperativas complejas dentro del SO (instalación de servicios, montaje de discos efímeros, descarga de modelos). Terraform puede ejecutar `remote-exec` provisioners, pero estos no son idempotentes por naturaleza, no se re-ejecutan en `terraform apply` subsiguientes, y dificultan el debugging. Los scripts Bash separados permiten re-ejecución manual, testing independiente y evolución sin redeployar infraestructura.

## Tecnologías Core

- **IaC**: Terraform (HCL) — proveedor `azurerm`
- **Scripting**: Bash (POSIX-compatible, ejecutado en Ubuntu 24.04)
- **Cloud**: Microsoft Azure (región East US 2)
- **GPU**: NVIDIA H100 NVL 94 GB (drivers preinstalados vía imagen HPC)
- **Imagen base**: `microsoft-dsvm:ubuntu-hpc:2404:latest` (Ubuntu 24.04 HPC con drivers NVIDIA/CUDA)
- **Servidor de modelos**: Ollama (API compatible OpenAI en puerto 11434)
- **Control de versiones**: Git + GitHub

## Decisiones Técnicas Clave

### Terraform por capas (no monolítico)
Cada capa de Terraform es un módulo o directorio independiente con su propio state, siguiendo el patrón de responsabilidad única:
- **Capa base**: grupo de recursos, registro de features/providers
- **Capa de red/seguridad**: VNet, Subnet, NSG, IP pública, reglas de acceso por `MY_IP`
- **Capa de cómputo**: VM GPU con disco OS, NIC, llave SSH
- **Capa de destrucción**: eliminación controlada de todos los recursos en orden inverso de dependencia

### Destrucción controlada (capa manual)
La destrucción del laboratorio es una capa de Terraform separada que ejecuta `terraform destroy` en orden inverso (compute → networking → foundation). Esta capa:
- Se ejecuta **exclusivamente de forma manual** (nunca automatizada ni en CI/CD).
- Respeta dependencias: destruye primero la VM, luego la red/seguridad, luego el grupo de recursos.
- Es idempotente: si un recurso ya no existe, no falla.
- Puede implementarse como un script orquestador Bash que invoca `terraform destroy` por capa en secuencia inversa, o como un directorio Terraform que importa los states de las capas anteriores.

### Scripts Bash numerados (no provisioners de Terraform)
Los scripts de configuración interna de la VM siguen el patrón `NN-descripcion.sh` (e.g., `01-montar-nvme.sh`, `02-instalar-ollama.sh`, `03-descargar-modelos.sh`). Cada script es idempotente: verifica el estado antes de actuar.

### Idempotencia como principio transversal
- Terraform: inherente por diseño declarativo; recursos con `lifecycle` y data sources para verificar existencia previa.
- Bash: cada script verifica si su acción ya fue ejecutada (`command -v`, `mountpoint -q`, `ollama list | grep`) antes de proceder.

### Seguridad: IP del desarrollador como variable
La variable `MY_IP` (IP pública de la máquina del desarrollador) se propaga a las reglas NSG para restringir SSH (22) y Ollama (11434). Nunca se abre al tráfico público general.

### Imagen Marketplace con aceptación de términos
Terraform debe gestionar la aceptación de términos de la imagen HPC y el registro de la feature `UseStandardSecurityType` para evitar Trusted Launch, de forma idempotente.

### Destrucción del laboratorio: excepción de provider
Al destruir el laboratorio (Ola 5 `teardown-docs`), se eliminan todos los recursos creados por Terraform **excepto** el registro del provider `Microsoft.Compute` y su feature `UseStandardSecurityType`. Estos registros son a nivel de suscripción, no tienen costo, y des-registrarlos podría afectar otros recursos de la suscripción. Los recursos que gestionan estos registros deben protegerse con `lifecycle { prevent_destroy = true }` en Terraform.

## Estándares de Desarrollo

### Nombrado
- Archivos Terraform: `kebab-case.tf` (e.g., `main.tf`, `variables.tf`, `outputs.tf`)
- Scripts Bash: `NN-kebab-case.sh` con número de secuencia
- Variables Terraform: `snake_case`
- Recursos Azure: convención `prefijo-funcion` (e.g., `vm-ollama-h100`, `vm-ollama-h100-pip`)

### Calidad de código
- Terraform: `terraform fmt` y `terraform validate` antes de commit
- Bash: `shellcheck` para linting; `set -euo pipefail` en cada script
- Sin secretos hardcodeados; credenciales vía variables de entorno o archivos `.tfvars` (excluidos del repositorio)

## Entorno de Desarrollo

### Herramientas requeridas
- Terraform >= 1.5
- Azure CLI (`az`) — para autenticación del proveedor Terraform
- SSH client — para conexión a la VM y ejecución de scripts
- shellcheck (recomendado) — linting de scripts Bash

### Comandos comunes
```bash
# Infraestructura
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Configuración de la VM (vía SSH)
ssh -i ~/.ssh/ollama_h100.pem azureuser@<IP>
bash scripts/01-montar-nvme.sh
bash scripts/02-instalar-ollama.sh
bash scripts/03-descargar-modelos.sh

# Operación diaria
az vm start --resource-group grre_desarrollo_lab --name vm-ollama-h100
az vm deallocate --resource-group grre_desarrollo_lab --name vm-ollama-h100
```

---
_Documenta estándares y patrones, no cada dependencia_
