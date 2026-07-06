# Visión del Producto

Laboratorio de Infraestructura como Código (IaC) que despliega una máquina virtual GPU en Azure (`Standard_NC40ads_H100_v5`, 1x NVIDIA H100 NVL de 94 GB) con Ollama preconfigurado para servir modelos LLM de contexto largo, consumibles desde herramientas de desarrollo local (VSCode + GitHub Copilot, ForgeCode, Cline, Continue.dev).

## Capacidades Core

1. **Despliegue declarativo de infraestructura Azure** — grupo de recursos, red, seguridad y VM GPU mediante Terraform por capas, ejecutado remotamente desde la máquina del desarrollador.
2. **Configuración automatizada post-despliegue** — instalación de Ollama, montaje de NVMe efímero, descarga de modelos LLM mediante scripts Bash secuenciales ejecutados dentro de la VM.
3. **Operación diaria simplificada** — ciclo encender/usar/apagar con `az vm start`/`deallocate` para minimizar costos; los modelos se re-descargan al iniciar sesión porque el NVMe es efímero.
4. **Destrucción controlada del laboratorio** — capa de Terraform dedicada, de ejecución exclusivamente manual, que elimina todos los recursos en orden inverso de dependencia (VM → red → grupo de recursos), de forma idempotente y sin dejar recursos huérfanos.

## Casos de Uso Objetivo

- Desarrollador individual que necesita acceso a LLMs de alta capacidad (30B–80B parámetros) con contexto largo (hasta 256K tokens) para asistencia de código y razonamiento.
- Laboratorio educativo o de experimentación con modelos LLM en hardware GPU cloud sin comprometer una suscripción a APIs comerciales.
- Entorno de pruebas para evaluar diferentes cuantizaciones y modelos MoE/densos en una sola GPU de 94 GB.

## Propuesta de Valor

- **Costo controlado**: la VM solo cobra cómputo mientras está encendida (~$6.98/h); apagada, el costo pasivo es ~$9/mes (disco + IP).
- **Reproducible e idempotente**: todo el despliegue es repetible sin efectos secundarios; si un recurso ya existe, se omite su creación.
- **Seguridad por defecto**: acceso SSH y API de Ollama restringidos exclusivamente a la IP pública del desarrollador (`MY_IP`) mediante NSG.
- **Sin dependencia de APIs comerciales**: los modelos corren localmente en la VM con Ollama, sin límites de rate ni costos por token.

---
_Enfocado en propósito y valor, no en listas exhaustivas de features_
