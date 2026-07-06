# Guía completa: VM GPU (1x H100) en Azure con Ollama y contexto largo

Despliegue paso a paso, idempotente y explicativo, de una máquina virtual `NC40ads_H100_v5` (1 GPU NVIDIA H100 NVL de 94 GB) en Azure para servir modelos LLM con Ollama, con llave SSH en formato `.pem` descargable, expuestos por IP pública y consumibles desde VSCode + GitHub Copilot y ForgeCode.

---

## Índice

1. [Resumen de la arquitectura y decisiones finales](#1-resumen-de-la-arquitectura-y-decisiones-finales)
2. [Especificaciones del despliegue](#2-especificaciones-del-despliegue)
3. [Fase 0: Requisitos previos](#fase-0-requisitos-previos)
4. [Fase 1: Variables base](#fase-1-variables-base)
5. [Fase 2: Generar la llave SSH en formato PEM](#fase-2-generar-la-llave-ssh-en-formato-pem-descargable)
6. [Fase 3: Despliegue de la infraestructura (Azure CLI)](#fase-3-despliegue-de-la-infraestructura-azure-cli-idempotente)
7. [Fase 4: Descargar el archivo .pem a tu Mac](#fase-4-descargar-el-archivo-pem-a-tu-mac)
8. [Fase 5: Configuración dentro de Ubuntu](#fase-5-configuración-dentro-de-ubuntu-idempotente)
9. [Fase 6: Verificación](#fase-6-verificación-de-que-todo-opera)
10. [Fase 7: Configurar los clientes en la MacBook](#fase-7-configurar-los-clientes-en-la-macbook)
11. [Fase 8: Operación diaria](#fase-8-operación-diaria-encender-usar-apagar)
12. [Presupuesto de VRAM: por qué estos tags y estas cuantizaciones](#presupuesto-de-vram-por-qué-estos-tags-y-estas-cuantizaciones)
13. [Resumen de costos pasivos](#resumen-de-costos-pasivos)
14. [Enlaces de referencia](#enlaces-de-referencia)
15. [Enlaces para profundizar](#enlaces-para-profundizar)

---

## 1. Resumen de la arquitectura y decisiones finales

Esta versión de la guía incorpora tres decisiones finales respecto a versiones anteriores:

- **Familia de cómputo:** `Standard_NC40ads_H100_v5` (40 vCPUs, 1 GPU NVIDIA H100 NVL de 94 GB de VRAM, 320 GiB de RAM). Se eligió esta en lugar del NC80adis porque es la que tiene capacidad disponible en East US 2; el NC80adis (2 GPUs) no aparecía como desplegable por falta de capacidad en la región.
- **Llave SSH en formato `.pem` descargable:** en lugar de dejar que la CLI genere la llave por defecto, la generamos explícitamente en formato PEM con `ssh-keygen -m PEM`, de modo que tengas un archivo `.pem` claro para descargar y usar desde tu Mac.
- **Modelos ajustados a una sola GPU de 94 GB:** las cuantizaciones se recalcularon para caber en 94 GB junto con el KV cache del contexto largo. El modelo de código baja a Q4_K_M porque en Q8 no cabría con contexto amplio en una sola GPU.

Los modelos se ejecutan de uno en uno (nunca los tres a la vez), lo que permite que cada uno disponga de toda la VRAM. Los modelos viven en el disco NVMe local efímero, que se borra al hacer `deallocate`, por lo que se re-descargan al reiniciar. El proveedor de modelos es Ollama; no se necesita vLLM.

---

## 2. Especificaciones del despliegue

| Elemento | Valor |
|---|---|
| Región | East US 2 |
| Grupo de recursos | `grre_desarrollo_lab` |
| Tamaño de VM | `Standard_NC40ads_H100_v5` (1x H100 NVL, 94 GB VRAM, 320 GiB RAM) |
| Imagen | `microsoft-dsvm:ubuntu-hpc:2404:latest` (drivers NVIDIA y CUDA preinstalados) |
| Disco de OS | Standard SSD (`StandardSSD_LRS`), 64 GB |
| Almacenamiento de modelos | NVMe local efímero (montado en `/mnt/ollama`) |
| Autenticación | Llave SSH RSA 4096 en formato PEM (`.pem` descargable) |
| Proveedor de modelos | Ollama |
| Puerto de Ollama | 11434 |

**Modelos LLM (uno a la vez), ajustados a 1 GPU de 94 GB:**

| Modelo | Tag de Ollama | Pesos aprox. | Arquitectura |
|---|---|---|---|
| Qwen3 30B Thinking (2507) | `qwen3:30b-a3b-thinking-2507-q8_0` | 32 GB | MoE |
| Gemma 4 31B denso | `gemma4:31b-it-q8_0` | 34 GB | Densa |
| Qwen3-Coder-Next 80B-A3B | `qwen3-coder-next:q4_K_M` | 52 GB | MoE |

---

## Fase 0: Requisitos previos

Estos comandos se ejecutan en tu terminal (Azure Cloud Shell o tu Mac con Azure CLI). Validan versión y sesión sin duplicar nada.

```bash
# Verifica que az CLI existe; si no, indica cómo instalarlo
command -v az >/dev/null 2>&1 || { echo "Instala Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"; }

# Inicia sesión solo si no hay una cuenta activa (idempotente)
az account show >/dev/null 2>&1 || az login

# Fija la suscripción correcta (reemplaza por tu ID)
az account set --subscription "TU_SUBSCRIPTION_ID"
az account show --output table
```

Verifica que tienes cuota para la familia en East US 2 (necesitas al menos 40 vCPUs libres):

```bash
az vm list-usage --location eastus2 \
  --query "[?contains(localName, 'NCadsH100v5')]" --output table
```

---

## Fase 1: Variables base

Centraliza toda la configuración. Ajusta `MY_IP` con la IP pública de tu MacBook para restringir el acceso.

```bash
# --- Identidad del despliegue ---
export RG="grre_desarrollo_lab"
export LOCATION="eastus2"
export VM_NAME="vm-ollama-h100"
export VM_SIZE="Standard_NC40ads_H100_v5"
export IMAGE_URN="microsoft-dsvm:ubuntu-hpc:2404:latest"
export ADMIN_USER="azureuser"

# --- Disco de sistema operativo ---
export OS_DISK_SIZE_GB="64"
export OS_DISK_SKU="StandardSSD_LRS"

# --- Llave SSH en formato PEM ---
export KEY_DIR="$HOME/.ssh"
export KEY_NAME="ollama_h100.pem"
export KEY_PATH="${KEY_DIR}/${KEY_NAME}"

# --- Red ---
export PIP_NAME="${VM_NAME}-pip"
export NSG_NAME="${VM_NAME}NSG"
export OLLAMA_PORT="11434"

# --- Tu IP pública (para restringir SSH y Ollama) ---
export MY_IP="$(curl -s https://api.ipify.org)/32"
echo "Tu IP pública detectada: $MY_IP"
```

---

## Fase 2: Generar la llave SSH en formato PEM (descargable)

En lugar de `--generate-ssh-keys` (que crea `id_rsa` sin extensión), generamos explícitamente un par de llaves en formato PEM. Así obtienes un archivo `.pem` claro. El comando es idempotente: solo crea la llave si no existe.

```bash
mkdir -p "$KEY_DIR"

# Genera el par en formato PEM solo si aún no existe
if [ -f "$KEY_PATH" ]; then
  echo "La llave $KEY_PATH ya existe. Omitiendo generación."
else
  ssh-keygen -m PEM -t rsa -b 4096 -C "${ADMIN_USER}@ollama-h100" -f "$KEY_PATH" -N ""
  echo "Llave PEM generada en $KEY_PATH"
fi

# Ajusta permisos de la llave privada
chmod 600 "$KEY_PATH"

# Verifica que existan la privada (.pem) y la pública (.pem.pub)
ls -al "${KEY_PATH}" "${KEY_PATH}.pub"
```

> El flag `-m PEM` fuerza el formato PEM (Privacy-Enhanced Mail). Se generan dos archivos: `ollama_h100.pem` (privada, la que descargarás y usarás con `ssh -i`) y `ollama_h100.pem.pub` (pública, la que se instala en la VM). El `-N ""` crea la llave sin passphrase para simplicidad de laboratorio; para mayor seguridad puedes poner una passphrase reemplazando `""` por tu frase.

---

## Fase 3: Despliegue de la infraestructura (Azure CLI, idempotente)

### 3.1 Grupo de recursos

```bash
if [ "$(az group exists --name "$RG")" = "false" ]; then
  az group create --name "$RG" --location "$LOCATION" --output table
else
  echo "El grupo $RG ya existe. Omitiendo."
fi
```

### 3.2 Registrar la feature para securityType Standard (evita Trusted Launch)

La imagen HPC es Gen2 y por defecto usa Trusted Launch (Secure Boot), que puede interferir con los drivers NVIDIA. Para usar `--security-type Standard` hay que registrar una feature una sola vez. Esto no tiene costo.

```bash
# Registra la feature solo si no está ya registrada
STATE="$(az feature show --namespace Microsoft.Compute --name UseStandardSecurityType --query 'properties.state' -o tsv 2>/dev/null || echo 'NotRegistered')"
if [ "$STATE" != "Registered" ]; then
  az feature register --namespace Microsoft.Compute --name UseStandardSecurityType
  echo "Esperando registro de la feature (puede tardar varios minutos)..."
  until [ "$(az feature show --namespace Microsoft.Compute --name UseStandardSecurityType --query 'properties.state' -o tsv)" = "Registered" ]; do
    echo "  ...aún registrando, reintento en 30s"
    sleep 30
  done
  az provider register --namespace Microsoft.Compute
fi
echo "Feature UseStandardSecurityType: Registered"
```

### 3.3 Aceptar términos de la imagen (si aplica)

```bash
az vm image terms accept --urn "$IMAGE_URN" 2>/dev/null \
  && echo "Términos aceptados." \
  || echo "La imagen no requiere aceptar términos. Continuando."
```

### 3.4 Crear la máquina virtual con la llave PEM pública

Nota clave: usamos `--ssh-key-values "${KEY_PATH}.pub"` para instalar TU llave pública PEM, en lugar de `--generate-ssh-keys`. Así la VM queda atada al `.pem` que generaste.

```bash
if az vm show --resource-group "$RG" --name "$VM_NAME" >/dev/null 2>&1; then
  echo "La VM $VM_NAME ya existe. Omitiendo creación."
else
  az vm create \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --location "$LOCATION" \
    --size "$VM_SIZE" \
    --image "$IMAGE_URN" \
    --security-type Standard \
    --os-disk-size-gb "$OS_DISK_SIZE_GB" \
    --storage-sku "$OS_DISK_SKU" \
    --public-ip-address "$PIP_NAME" \
    --public-ip-sku Standard \
    --public-ip-address-allocation Static \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values "${KEY_PATH}.pub" \
    --nsg-rule NONE \
    --output table
fi
```

### 3.5 Reglas de red (NSG): SSH y Ollama restringidos a tu IP

```bash
# Regla SSH (22)
az network nsg rule show --resource-group "$RG" --nsg-name "$NSG_NAME" --name Allow-SSH >/dev/null 2>&1 || \
az network nsg rule create \
  --resource-group "$RG" --nsg-name "$NSG_NAME" --name Allow-SSH \
  --priority 1000 --protocol Tcp --direction Inbound --access Allow \
  --destination-port-ranges 22 --source-address-prefixes "$MY_IP" --output none

# Regla Ollama (11434)
az network nsg rule show --resource-group "$RG" --nsg-name "$NSG_NAME" --name Allow-Ollama >/dev/null 2>&1 || \
az network nsg rule create \
  --resource-group "$RG" --nsg-name "$NSG_NAME" --name Allow-Ollama \
  --priority 1010 --protocol Tcp --direction Inbound --access Allow \
  --destination-port-ranges "$OLLAMA_PORT" --source-address-prefixes "$MY_IP" --output none

echo "Reglas NSG configuradas."
```

> **Advertencia de seguridad:** Ollama no tiene autenticación propia. Restringir el puerto 11434 a tu IP (`$MY_IP`) es la protección mínima. Abrirlo a todo internet (`"Internet"`) dejaría tu GPU accesible a cualquiera; si lo necesitas, añade una capa como reverse proxy con API key o una VPN (Tailscale).

### 3.6 Obtener la IP pública de la VM

```bash
export VM_PUBLIC_IP="$(az vm show -d --resource-group "$RG" --name "$VM_NAME" --query publicIps -o tsv)"
echo "IP pública de la VM: $VM_PUBLIC_IP"
```

---

## Fase 4: Descargar el archivo .pem a tu Mac

Si estás trabajando desde Azure Cloud Shell, la llave `.pem` está dentro de Cloud Shell y necesitas traerla a tu Mac. Cloud Shell persiste tu `$HOME`, así que la llave sigue ahí entre sesiones, pero para usarla localmente debes descargarla.

**Opción A (la más simple): comando `download` de Cloud Shell.**

```bash
download ~/.ssh/ollama_h100.pem
```

Esto abre el diálogo del navegador para guardar el `.pem` en tu Mac.

**Opción B: mostrar el contenido y pegarlo en tu Mac.**

```bash
cat ~/.ssh/ollama_h100.pem
```

Copias el bloque completo (desde `-----BEGIN RSA PRIVATE KEY-----` hasta `-----END RSA PRIVATE KEY-----`) y en tu Mac lo guardas:

```bash
# En tu Mac
mkdir -p ~/.ssh
nano ~/.ssh/ollama_h100.pem   # pega el contenido y guarda
chmod 600 ~/.ssh/ollama_h100.pem
```

> Si ejecutas todo directamente desde tu Mac (no Cloud Shell), este paso no aplica: la llave ya está en `~/.ssh/ollama_h100.pem`.

---

## Fase 5: Configuración dentro de Ubuntu (idempotente)

Conéctate por SSH usando el `.pem` explícitamente con `-i`:

```bash
ssh -i ~/.ssh/ollama_h100.pem ${ADMIN_USER}@${VM_PUBLIC_IP}
```

Todo lo que sigue se ejecuta dentro de la VM.

### 5.1 Verificar que la GPU está lista

```bash
nvidia-smi
```

Debes ver 1 GPU H100 NVL con 94 GB. La imagen HPC ya trae los drivers, así que no instalas nada.

### 5.2 Montar el NVMe efímero para los modelos

Script idempotente que detecta los discos NVMe locales efímeros, los formatea y los monta en `/mnt/ollama`.

```bash
sudo tee /usr/local/sbin/setup-ephemeral-ollama.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
MOUNT_POINT="/mnt/ollama"
MODELS_DIR="${MOUNT_POINT}/models"
LOCAL_BASE="/dev/disk/azure/local/by-index"

if mountpoint -q "$MOUNT_POINT"; then
  echo "[setup] $MOUNT_POINT ya está montado."
  mkdir -p "$MODELS_DIR"; chown -R ollama:ollama "$MOUNT_POINT" 2>/dev/null || true
  exit 0
fi

command -v mdadm >/dev/null 2>&1 || { apt-get update -y && apt-get install -y mdadm xfsprogs; }

mapfile -t IDX < <(ls "$LOCAL_BASE" 2>/dev/null | grep -E '^[0-9]+$' | sort -n)
if [ "${#IDX[@]}" -eq 0 ]; then
  echo "[setup] No se detectaron discos NVMe locales."; exit 1
fi

DEVICES=()
for i in "${IDX[@]}"; do DEVICES+=("$(readlink -f "${LOCAL_BASE}/${i}")"); done
echo "[setup] Discos locales detectados: ${DEVICES[*]}"

if [ "${#DEVICES[@]}" -eq 1 ]; then
  TARGET="${DEVICES[0]}"
  mkfs.xfs -f "$TARGET"
else
  mdadm --create /dev/md0 --level=0 --force --run \
        --raid-devices="${#DEVICES[@]}" "${DEVICES[@]}"
  TARGET="/dev/md0"
  mkfs.xfs -f "$TARGET"
fi

mkdir -p "$MOUNT_POINT"
mount -o discard "$TARGET" "$MOUNT_POINT"
mkdir -p "$MODELS_DIR"
chown -R ollama:ollama "$MOUNT_POINT"
echo "[setup] NVMe efímero montado en $MOUNT_POINT."
EOF

sudo chmod +x /usr/local/sbin/setup-ephemeral-ollama.sh
```

Servicio systemd para que se monte en cada arranque, antes de Ollama:

```bash
sudo tee /etc/systemd/system/setup-ephemeral-ollama.service >/dev/null <<'EOF'
[Unit]
Description=Formatea y monta el NVMe efimero para Ollama
DefaultDependencies=no
After=local-fs.target
Before=ollama.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/setup-ephemeral-ollama.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable setup-ephemeral-ollama.service
```

### 5.3 Instalar Ollama (idempotente)

```bash
command -v ollama >/dev/null 2>&1 || curl -fsSL https://ollama.com/install.sh | sh
ollama --version
```

Monta el NVMe por primera vez (el usuario `ollama` ya existe tras la instalación):

```bash
sudo systemctl start setup-ephemeral-ollama.service
df -h /mnt/ollama
```

### 5.4 Configurar el servicio de Ollama

Drop-in de systemd con todas las variables: exposición en red, ruta de modelos en el NVMe efímero, contexto largo, Flash Attention y KV cache q8_0 (imprescindibles para que el contexto quepa en una sola GPU).

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null <<'EOF'
[Unit]
Requires=setup-ephemeral-ollama.service
After=setup-ephemeral-ollama.service

[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
Environment="OLLAMA_MODELS=/mnt/ollama/models"
Environment="OLLAMA_CONTEXT_LENGTH=262144"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
Environment="OLLAMA_KEEP_ALIVE=30m"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verifica que tomó las variables:

```bash
sudo systemctl show ollama --property=Environment
```

### 5.5 Descargar los tres modelos (idempotente)

```bash
for M in \
  "qwen3:30b-a3b-thinking-2507-q8_0" \
  "gemma4:31b-it-q8_0" \
  "qwen3-coder-next:q4_K_M"
do
  if ollama list | grep -q "$M"; then
    echo "Modelo $M ya presente. Omitiendo."
  else
    echo "Descargando $M ..."
    ollama pull "$M"
  fi
done

ollama list
```

---

## Fase 6: Verificación de que todo opera

```bash
# Carga un modelo y revisa que corra en GPU
ollama run qwen3:30b-a3b-thinking-2507-q8_0 "Responde solo: OK"
ollama ps    # PROCESSOR debe indicar GPU; CONTEXT muestra el contexto asignado
nvidia-smi   # confirma uso de VRAM
```

Prueba el endpoint remoto desde tu Mac:

```bash
curl http://${VM_PUBLIC_IP}:11434/api/chat -d '{
  "model": "qwen3-coder-next:q4_K_M",
  "messages": [{"role":"user","content":"Di hola en una palabra"}],
  "options": {"num_ctx": 131072},
  "stream": false
}'
```

> Si `ollama ps` muestra CPU en vez de GPU, el KV cache desbordó la VRAM. Baja `num_ctx` (por ejemplo a 131072 o 65536) hasta que vuelva a GPU. En una sola H100, el modelo de código en Q4_K_M admite contexto amplio, pero 256K completos pueden requerir este ajuste.

---

## Fase 7: Configurar los clientes en la MacBook

Ambas herramientas apuntan a `http://${VM_PUBLIC_IP}:11434`.

**VSCode + GitHub Copilot:** en el selector de modelos, gestiona modelos, elige Ollama como proveedor, indica la URL del servidor (IP pública y puerto 11434) y selecciona el modelo. El modo agente de Copilot con Ollama local puede ser frágil; para uso agéntico robusto considera Cline, Continue.dev, OpenCode o Aider.

**ForgeCode:** configúralo como proveedor compatible con la API de Ollama apuntando a `http://${VM_PUBLIC_IP}:11434` y selecciona `qwen3-coder-next:q4_K_M`, que trae tool calling nativo.

---

## Fase 8: Operación diaria (encender, usar, apagar)

**Al iniciar la jornada**, desde tu Mac:

```bash
az vm start --resource-group "$RG" --name "$VM_NAME"
export VM_PUBLIC_IP="$(az vm show -d -g "$RG" -n "$VM_NAME" --query publicIps -o tsv)"
ssh -i ~/.ssh/ollama_h100.pem ${ADMIN_USER}@${VM_PUBLIC_IP}
```

Dentro, el NVMe se remonta solo; re-descarga el modelo que usarás esa sesión (el almacenamiento efímero se borró al apagar):

```bash
ollama pull qwen3-coder-next:q4_K_M   # o el que necesites hoy
```

**Al terminar**, desasigna la VM para no pagar cómputo:

```bash
az vm deallocate --resource-group "$RG" --name "$VM_NAME"
```

> **Distinción crítica:** `az vm deallocate` (estado "Stopped/Deallocated") detiene el cobro del cómputo. Apagar con `shutdown` desde Linux deja la VM asignada y se sigue cobrando. Con la VM desasignada solo pagas los costos pasivos (disco de OS e IP pública).

---

## Presupuesto de VRAM: por qué estos tags y estas cuantizaciones

En una sola H100 de 94 GB deben convivir los pesos del modelo y el KV cache del contexto. Como corres un modelo a la vez, cada uno dispone de los 94 GB. Con Flash Attention y KV cache en q8_0 activos, el contexto largo se vuelve manejable.

| Modelo | Tag | Pesos en VRAM | VRAM libre para KV cache | Contexto en 1 GPU |
|---|---|---|---|---|
| Qwen3 30B Thinking | `qwen3:30b-a3b-thinking-2507-q8_0` | ~32 GB | ~62 GB | 256K con holgura |
| Gemma 4 31B denso | `gemma4:31b-it-q8_0` | ~34 GB | ~60 GB | 256K con holgura |
| Qwen3-Coder-Next | `qwen3-coder-next:q4_K_M` | ~52 GB | ~42 GB | Amplio; 256K completos pueden requerir ajustar num_ctx |

Notas de las decisiones:

- El tag `qwen3:30b-a3b-thinking-2507-fp16` no existe en la biblioteca oficial de Ollama; su máxima calidad publicada práctica es `-q8_0`, que además cabe de sobra. Por eso se usa Q8.
- Para Gemma denso, `-q8_0` da calidad casi idéntica a BF16 con mucho más margen de contexto, por lo que es la opción recomendada frente a `-bf16` (63 GB) en una sola GPU.
- El Coder-Next en `q8_0` (85 GB) no cabe con contexto largo en 94 GB (deja solo ~9 GB para KV cache). En `q4_K_M` (52 GB) libera ~42 GB para el contexto. Al ser un MoE grande, Q4 conserva buena calidad para trabajo agéntico.

---

## Resumen de costos pasivos

Costos que siguen cobrándose con la VM apagada (desasignada). Confirma valores exactos en la calculadora oficial de Azure para East US 2.

| Recurso | ¿Pasivo? | Estimado mensual aprox. |
|---|---|---|
| Cómputo VM (1x H100) | No — pago por uso | ~6.98 USD/hora solo encendida |
| Disco de OS Standard SSD 64 GB (E6) | Sí | ~5 USD/mes |
| IP pública estática (Standard) | Sí | ~3.65 USD/mes |
| Modelos en NVMe efímero | No | 0 USD (se borran al apagar) |

> Con la VM encendida 1 hora al día (~30 h/mes), el cómputo ronda ~209 USD/mes, más ~9 USD/mes de costos pasivos.

---

## Enlaces de referencia

- Especificaciones de la serie NCads H100 v5 (NC40ads: 1 GPU H100 NVL de 94 GB) — https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/gpu-accelerated/ncadsh100v5-series
- Crear y usar un par de llaves SSH para VMs Linux en Azure (formato PEM con `ssh-keygen -m PEM` y uso de `--ssh-key-values`) — https://learn.microsoft.com/en-us/azure/virtual-machines/linux/mac-create-ssh-keys
- Pasos detallados para crear un par de llaves SSH (formato PEM, permisos y passphrase) — https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-ssh-keys-detailed
- Persistir archivos y descargar desde Azure Cloud Shell (comando `download`) — https://learn.microsoft.com/en-us/azure/cloud-shell/persisting-shell-storage
- FAQ oficial de Trusted Launch (registro de la feature `UseStandardSecurityType` para `securityType Standard`) — https://learn.microsoft.com/en-us/azure/virtual-machines/trusted-launch-faq
- FAQ oficial de Ollama (systemd, OLLAMA_HOST, OLLAMA_MODELS, contexto, Flash Attention, KV cache q8_0) — https://docs.ollama.com/faq
- Tags oficiales de qwen3-coder-next (Q4_K_M) — https://ollama.com/library/qwen3-coder-next/tags
- Ficha oficial de gemma4:31b-it-q8_0 — https://ollama.com/library/gemma4
- Tags oficiales de qwen3 (30b-a3b-thinking-2507-q8_0) — https://ollama.com/library/qwen3/tags

---

## Enlaces para profundizar

- Referencia de `az vm create` (`--ssh-key-values`, `--security-type`, `--os-disk-size-gb`) — https://learn.microsoft.com/en-us/cli/azure/vm#az-vm-create
- Crear y almacenar llaves SSH con Azure CLI (`az sshkey create`) — https://learn.microsoft.com/en-us/azure/virtual-machines/ssh-keys-azure-cli
- Formatear y montar discos NVMe temporales en VMs Linux de Azure — https://learn.microsoft.com/en-us/azure/virtual-machines/linux/disks-format-mount-temp-disks-linux
- Estados de facturación de una VM (Stopped vs Deallocated) — https://learn.microsoft.com/en-us/azure/virtual-machines/states-billing
- Solucionar fallos de asignación (AllocationFailed) por capacidad de GPU — https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/windows/allocation-failure
- Model card oficial de Qwen3-Coder-Next (reducir contexto si falla por memoria) — https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF
- Calculadora oficial de precios de Azure (VM, disco e IP en East US 2) — https://azure.microsoft.com/en-us/pricing/calculator/

---

*Documento generado como guía de laboratorio. Verifica siempre precios, disponibilidad de imágenes, tamaños y tags de modelos en la documentación oficial de Azure y Ollama para tu suscripción y región antes de desplegar.*
