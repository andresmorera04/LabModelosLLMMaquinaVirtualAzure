# Análisis de Brecha (Gap Analysis) — Capa `networking`

_Generado por `/kiro-validate-gap networking`. Informa la fase de diseño; no toma decisiones finales de implementación._

## 1. Estado Actual del Código (Current State)

### Activos existentes relacionados

| Activo | Ubicación | Relevancia para `networking` |
|---|---|---|
| Capa `foundation` (completa: req/design/tasks) | `terraform/01-foundation/` | Dependencia directa; fuente de patrón a replicar |
| `providers.tf` | `terraform/01-foundation/providers.tf` | Patrón de provider `azurerm` a reutilizar tal cual |
| `main.tf` | `terraform/01-foundation/main.tf` | Patrón de recurso + `tags` + `lifecycle` |
| `variables.tf` | `terraform/01-foundation/variables.tf` | Patrón de variables (tipo, descripción, nullable, defaults) |
| `outputs.tf` | `terraform/01-foundation/outputs.tf` | Expone `resource_group_name`, `resource_group_id`, `location` |
| `terraform.tfvars.example` | `terraform/01-foundation/` | Patrón de plantilla documentada versionada |
| `.gitignore` | raíz | Ya cubre `*.tfstate`, `*.tfvars` (excepto `.example`), `.terraform/`, `*.pem` |
| Directorio `terraform/02-networking/` | — | **No existe todavía** (greenfield dentro de un patrón establecido) |

### Convenciones extraídas (a heredar)

- **Estructura de archivos por capa**: `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tfvars.example`.
- **Provider `azurerm`**: `required_version >= 1.5`, `azurerm >= 4.0`, `features {}`, `resource_provider_registrations = "none"`; autenticación con `subscription_id` (obligatorio, sin default) y `client_id`/`client_secret`/`tenant_id` (`default = null`, `sensitive = true`, fallback a env vars `ARM_*`).
- **Variables**: `snake_case`, siempre con `type` y `description` en español; defaults seguros solo para valores no sensibles (`location = "eastus2"`, `tags = {}`).
- **Nombrado de recursos Azure**: `prefijo-funcion` (p. ej. `vm-ollama-h100-pip`, `vm-ollama-h100NSG` en la guía base).
- **Etiquetas**: `tags = var.tags` en cada recurso; sin valores fijos en código.
- **Estado**: backend **local** (sin bloque `backend`), un state por capa.
- **`prevent_destroy`**: solo donde se justifica (en `foundation`, el registro de provider). No hay recurso análogo en `networking`.

### Superficies de integración

- **Entrada**: nombre del grupo de recursos y región producidos por `foundation`.
- **Salida**: identificador de subred, IP pública (valor + id) e identificador de NSG, para consumo de `03-compute`.
- **Referencia funcional (source of truth del "qué")**: `guia-vm-ollama-nc40ads-h100.md`, secciones 3.4–3.6 (IP pública `Static`, NSG con reglas `Allow-SSH`/`Allow-Ollama` restringidas a `MY_IP`).

## 2. Análisis de Factibilidad de Requisitos (Requirement-to-Asset Map)

| Req | Necesidad técnica | Activo existente | Brecha |
|---|---|---|---|
| 1. Consumo de `foundation` | Recibir `resource_group_name` + `location` | Outputs de `foundation` disponibles | **Constraint** — mecanismo de consumo ya decidido (ver §5, Hallazgo crítico) |
| 2. VNet + Subnet | `azurerm_virtual_network`, `azurerm_subnet` | Ninguno (nuevo) | **Missing** — recursos estándar, patrón claro |
| 3. IP pública estática | `azurerm_public_ip` (`allocation_method = Static`, SKU `Standard`) | Guía 3.4 (`--public-ip-address-allocation Static`) | **Missing** — recurso estándar |
| 4. NSG restringido a `my_ip` | `azurerm_network_security_group` + reglas 22/11434 desde `my_ip`; asociación al ámbito de red | Guía 3.5 (reglas `Allow-SSH`/`Allow-Ollama`) | **Missing** + decisión de ámbito de asociación (ver §5) |
| 5. Outputs para `compute` | `azurerm_subnet.id`, `azurerm_public_ip.id`/`.ip_address`, `azurerm_network_security_group.id` | Patrón `outputs.tf` de `foundation` | **Missing** — trivial |
| 6. Parametrización sin hardcodeo | `variables.tf` + `terraform.tfvars.example` | Patrón de `foundation` | **Missing** — replicar patrón |
| 7. Idempotencia y calidad | `fmt`/`validate`, `plan` a cero cambios | Recursos azurerm nativamente idempotentes | **Sin brecha** — sin caso de `import` como en `foundation` |

### Señales de complejidad

- Recursos Azure **estándar y bien soportados** por `azurerm` v4 (VNet, Subnet, Public IP, NSG). Sin integraciones externas.
- **Sin** el problema chicken-and-egg ni el `terraform import` de primera ejecución que afecta a `foundation` (ese riesgo era exclusivo del registro de provider).
- La única complejidad real es de **decisión de diseño**, no técnica (mecanismo de consumo de `foundation` y ámbito de asociación del NSG).

## 3. Opciones de Enfoque de Implementación

Contexto: `terraform/02-networking/` no existe. Por el patrón "una capa = un directorio independiente", **crear una nueva capa** es la única opción estructural sensata (Opción B). Las alternativas reales están en **cómo consume `foundation`**:

### Opción A — Nueva capa que consume `foundation` vía variables de entrada (paso manual)
- El desarrollador ejecuta `terraform output` en `foundation` y pasa `resource_group_name`/`location` a `networking` como `-var` o vía `terraform.tfvars`.
- ✅ **Alineada con la decisión ya tomada en `foundation`** (`research.md` §"Estado local", Opción 3 seleccionada; design.md línea 432).
- ✅ Cero acoplamiento entre states; máxima simplicidad; consistente con el resto del laboratorio.
- ❌ Paso manual entre capas (aceptable para un laboratorio de un solo desarrollador, según la propia compensación documentada en `foundation`).

### Opción B — Nueva capa que consume `foundation` vía `terraform_remote_state` (backend local)
- `data "terraform_remote_state" "foundation"` apuntando a `../01-foundation/terraform.tfstate`.
- ✅ Elimina el paso manual; lee outputs automáticamente.
- ❌ **Contradice la decisión explícita de `foundation`** (que evaluó y descartó esta opción, `research.md` línea 60).
- ❌ Acopla `networking` a la ruta y formato del state file de `foundation`.

### Opción C — Híbrida (variable con default que puede rellenarse desde remote_state)
- Variables de entrada como mecanismo primario, documentando `terraform_remote_state` como alternativa opcional.
- ❌ Ambigüedad de dos caminos para un laboratorio pequeño; no aporta valor. No recomendada.

**Recomendación para diseño**: **Opción A**, para mantener coherencia con la decisión arquitectónica ya establecida en `foundation`. Esto exige **reconciliar el Requisito 1** de `networking` (ver §5).

## 4. Complejidad y Riesgo

- **Esfuerzo estimado**: **S (1–3 días)**. Justificación: cuatro recursos `azurerm` estándar replicando un patrón de capa ya existente y probado; sin integraciones externas ni lógica imperativa.
- **Riesgo**: **Bajo**. Justificación: tecnología familiar (`azurerm` v4), alcance claro, sin cambios arquitectónicos y sin el caso de `import` que complicó a `foundation`. El único punto de atención es una **decisión de diseño** (consumo de `foundation`), no un desconocido técnico.

## 5. Hallazgos Críticos y Recomendaciones para Diseño

### ⚠️ Hallazgo crítico — Tensión entre Requisito 1 y la decisión de `foundation`

`foundation` decidió explícitamente (`design.md` línea 100/432, `research.md` §"Estado local", Opción 3):

> _"Estado local. Las capas posteriores reciben los valores como variables de entrada."_

Se **evaluó y descartó** el consumo vía `terraform_remote_state` (Opción 2). Sin embargo, el `requirements.md` de `networking` (Requisito 1.1 y 1.3, y el Boundary Context) está redactado en términos de "obtener desde los outputs de la capa `foundation`" / "si los outputs no pueden leerse", lo que sugiere lectura automática de state.

**Acción recomendada** (elegir en fase de diseño o mediante ajuste ligero de requisitos):
- **(Preferido)** Alinear con `foundation`: consumir vía **variables de entrada** (`resource_group_name`, `location`). Reformular el Requisito 1 para hablar de "valores provistos por variables de entrada, obtenidos de los outputs de `foundation`" en lugar de lectura directa de state. Esto es un ajuste de redacción menor, no un cambio de alcance.
- **(Alternativa)** Si se prefiere automatizar, reabrir la decisión de `foundation` y adoptar `terraform_remote_state` de forma **consistente en todas las capas** (no solo en `networking`).

### Decisiones a resolver en `/kiro-spec-design`

1. **Mecanismo de consumo de `foundation`** → recomendado: variables de entrada (Opción A).
2. **Ámbito de asociación del NSG** (Req 4.6): a la **subred** (`azurerm_subnet_network_security_group_association`) para que la protección aplique sin depender de `compute` — enfoque limpio y alineado con el requisito. Confirmar en diseño frente a asociación a NIC (que sería propiedad de `compute`).
3. **SKU y asignación de la IP pública**: la guía usa `Static`; el SKU `Standard` exige `Static` y es el recomendado (persiste entre `deallocate`/`start`, ~3.65 USD/mes). Confirmar SKU `Standard`.
4. **Modelado de reglas NSG**: reglas como recursos `azurerm_network_security_rule` separados vs. bloques `security_rule` inline en el NSG (impacto en idempotencia y legibilidad).
5. **Parametrización de puertos**: exponer `22` y `11434` como variables (Req 6.1) vs. constantes; y modelar `my_ip` como variable **sensible/entorno** para no versionarla (Req 6.4).

### Research Needed (llevar a diseño)

- Confirmar en `azurerm` v4 la sintaxis vigente de `azurerm_public_ip` (`sku`, `allocation_method`) y de la asociación NSG↔subred.
- Verificar que el espacio de direcciones de la VNet/Subnet no colisione con rangos por defecto y sea parametrizable con defaults seguros.

## 6. Patrón de Referencia a Heredar (resumen accionable)

```
terraform/02-networking/
  providers.tf   # idéntico patrón a foundation (azurerm v4, auth nullable + ARM_*, registrations "none")
  variables.tf   # subscription_id (req), auth nullable, resource_group_name, location,
                 # vnet/subnet address spaces, my_ip (sensible), puertos, nombres, tags
  main.tf        # VNet, Subnet, Public IP (Static/Standard), NSG + reglas, asociación NSG↔subred
  outputs.tf     # subnet_id, public_ip_address, public_ip_id, nsg_id (snake_case, no sensibles)
  terraform.tfvars.example  # plantilla documentada, sin valores reales (my_ip como placeholder)
```

---

# Registro de Discovery y Decisiones de Diseño — Capa `networking`

_Generado por `/kiro-spec-design networking`. Complementa el análisis de brecha anterior con las decisiones tomadas para el diseño._

## Summary
- **Feature**: `networking`
- **Discovery Scope**: Extension (nueva capa Terraform hermana que replica el patrón probado de `foundation`)
- **Key Findings**:
  - El consumo de `foundation` se resuelve vía **variables de entrada** (alineado con la decisión ya tomada en `foundation`), no vía `terraform_remote_state` (Hallazgo crítico del gap analysis resuelto).
  - Los cuatro recursos (`azurerm_virtual_network`, `azurerm_subnet`, `azurerm_public_ip`, `azurerm_network_security_group`) son estándar en `azurerm` v4 y nativamente idempotentes; no requieren `terraform import` (a diferencia del registro de provider en `foundation`).
  - La denegación del tráfico no autorizado a los puertos 22/11434 se apoya en la regla por defecto `DenyAllInbound` de todo NSG de Azure; el diseño se compromete a **no** crear ninguna regla con origen `*`/`Internet` para esos puertos.

## Research Log

### Verificación de esquema de recursos azurerm v4
- **Context**: Confirmar contratos HCL de los recursos de red antes de escribir el diseño.
- **Sources Consulted**: Conocimiento consolidado del provider `hashicorp/azurerm` v4 (documentación de recursos de red); no se requirió investigación web al ser recursos estándar y bien soportados.
- **Findings**:
  - `azurerm_subnet` usa `address_prefixes` (lista) y no admite `location` ni `tags`.
  - `azurerm_public_ip` con `sku = "Standard"` exige `allocation_method = "Static"`; el atributo `ip_address` es conocido tras `apply`.
  - La asociación NSG↔subred se modela con `azurerm_subnet_network_security_group_association`.
  - Las reglas del NSG se declaran como bloques `security_rule` inline; no deben mezclarse con recursos `azurerm_network_security_rule` separados.
- **Implications**: Contratos HCL directos, sin adaptaciones; el diseño puede fijar firmas concretas.

## Design Decisions

### Decision: Consumo de `foundation` vía variables de entrada
- **Context**: Requisito 1 y Hallazgo crítico del gap analysis (tensión con la decisión de estado local de `foundation`).
- **Alternatives Considered**:
  1. `terraform_remote_state` (backend local) — descartada por `foundation` y crearía acoplamiento al state file.
  2. Variables de entrada pobladas desde `terraform output` de `foundation` — seleccionada.
- **Selected Approach**: `networking` declara `resource_group_name` y `location` como variables de entrada. El desarrollador las obtiene con `terraform -chdir=../01-foundation output -raw <output>` y las provee vía `terraform.tfvars`, `-var` o `TF_VAR_*`.
- **Rationale**: Coherencia con la decisión arquitectónica de `foundation`; cero acoplamiento entre states; máxima simplicidad para un laboratorio de un desarrollador.
- **Trade-offs**: Paso manual de valores entre capas (aceptable y ya asumido en `foundation`).
- **Follow-up**: `Req 1.3` se materializa como validación de variable requerida (falla en `plan` si falta), no como lectura de state.

### Decision: NSG asociado a la subred (no a la NIC)
- **Context**: Requisito 4.6 exige que las reglas se apliquen sin depender de `compute`.
- **Alternatives Considered**:
  1. Asociar el NSG a la NIC — la NIC es propiedad de `compute`, violaría la frontera.
  2. Asociar el NSG a la subred — seleccionada.
- **Selected Approach**: `azurerm_subnet_network_security_group_association` en esta capa; la protección aplica a toda NIC que `compute` conecte a la subred.
- **Rationale**: Mantiene la aplicación (enforcement) de seguridad dentro de la frontera de `networking`; no requiere que `compute` recuerde asociar el NSG.
- **Trade-offs**: Todas las NICs de la subred heredan las reglas (deseable en este laboratorio de una sola VM).

### Decision: IP pública `Standard` / `Static`
- **Context**: Requisito 3 (IP persistente entre ciclos `deallocate`/`start`).
- **Selected Approach**: `sku = "Standard"`, `allocation_method = "Static"`.
- **Rationale**: El SKU `Standard` (recomendado por la guía base) exige asignación estática y conserva la misma IP tras desasignar/iniciar la VM; evita reconfigurar herramientas locales. Costo pasivo ~3.65 USD/mes.
- **Trade-offs**: Costo pasivo de la IP reservada (documentado en la guía).

### Decision: `resource_provider_registrations = "none"`
- **Context**: Consistencia con `foundation` y evitar que el provider intente registrar namespaces.
- **Selected Approach**: Igual que `foundation`, se desactiva el auto-registro. Se asume que `Microsoft.Network` ya está registrado (estándar en suscripciones activas y garantizado tras aplicar `foundation`).
- **Rationale**: Consistencia de configuración del provider entre capas; el SP no necesita permisos de registro.
- **Trade-offs**: Si `Microsoft.Network` no estuviera registrado, `apply` falla; mitigación documentada (`az provider register --namespace Microsoft.Network`).

### Decision: `my_ip` como variable requerida no versionada
- **Context**: Requisitos 4.3, 4.4, 6.4 (IP del desarrollador provista por variable, no versionada).
- **Selected Approach**: `my_ip` sin `default` (obligatoria), en formato CIDR (`x.x.x.x/32`), con bloque `validation` de formato; se provee vía `terraform.tfvars` (excluido de git) o `TF_VAR_my_ip`. No se marca `sensitive` para mantener legible el `plan` durante revisión.
- **Rationale**: Fail-fast si falta o tiene formato inválido; la exclusión de git evita versionar el dato del entorno.
- **Trade-offs**: El valor aparece en la salida de `plan` (ya visible de todos modos en el portal de Azure).

## Architecture Pattern Evaluation

| Opción | Descripción | Fortalezas | Riesgos / Limitaciones | Notas |
|--------|-------------|-----------|------------------------|-------|
| Módulo plano por capa | Directorio Terraform con recursos de red directos | Consistente con `foundation`, simple, sin sobre-ingeniería | Ninguna relevante a esta escala | Seleccionada |
| Submódulos reutilizables | Abstraer VNet/NSG en módulos | Reutilización futura | Sobre-ingeniería para 4 recursos de una sola VM | Descartada |

## Risks & Mitigations
- `Microsoft.Network` no registrado (bajo) — Mitigación: `az provider register --namespace Microsoft.Network` (una sola vez); documentado.
- Solapamiento de espacios de direcciones con futuras redes (bajo) — Mitigación: defaults seguros (`10.0.0.0/16` / `10.0.1.0/24`) parametrizables.
- Regla NSG demasiado permisiva por error humano (medio) — Mitigación: `source_address_prefix = var.my_ip` fijo, sin variable de "abrir a internet"; validación de formato de `my_ip`; se confía en `DenyAllInbound` por defecto.

## References
- `guia-vm-ollama-nc40ads-h100.md` — Fases 3.4–3.6 (IP pública `Static`, reglas NSG `Allow-SSH`/`Allow-Ollama` restringidas a `MY_IP`).
- `.kiro/specs/foundation/design.md` — patrón de capa hermana replicado.
