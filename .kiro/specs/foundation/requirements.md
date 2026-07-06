# Requirements Document

## Introduction

La capa `foundation` (Ola 1 del roadmap) establece la base del despliegue en Azure para el laboratorio de LLMs con Ollama sobre VM GPU H100. Es la primera capa de Terraform (`terraform/01-foundation/`) y no depende de ninguna otra. Su responsabilidad es dejar la suscripción de Azure en un estado consistente y reproducible sobre el cual las capas posteriores (`networking`, `compute`) puedan construir: un grupo de recursos existente en la región objetivo y el registro de la feature/provider que habilita crear VMs con `Standard` security type (evitando Trusted Launch).

El desarrollador que opera el laboratorio ejecuta esta capa con Terraform de forma remota contra Azure. La capa debe ser idempotente (un segundo `terraform apply` no produce cambios) y no debe contener ningún valor de entrada hardcodeado: todo valor configurable (suscripción, nombre del grupo de recursos, región, prefijos de nombrado, etiquetas) se declara como variable y se provee externamente, siguiendo las mejores prácticas de Infraestructura como Código.

## Boundary Context

- **In scope**: Provisión idempotente del grupo de recursos; registro idempotente de la feature `UseStandardSecurityType` y re-registro del provider `Microsoft.Compute`; configuración del provider `azurerm` con autenticación no interactiva; parametrización completa vía variables (sin valores quemados); exposición de outputs (`resource_group_name`, `resource_group_id`, `location`) para consumo de capas posteriores; plantilla de variables versionada.
- **Out of scope**: Creación de red, subredes, NSG, IP pública (Ola 2 `networking`); creación de la VM, NIC, discos o llaves SSH (Ola 3 `compute`); configuración interna de la VM y Ollama (Ola 4 `vm-config`); destrucción del laboratorio y documentación de operación (Ola 5 `teardown-docs`).
- **Adjacent expectations**: Las capas `networking` y `compute` consumirán los outputs de esta capa (nombre del grupo de recursos y región) mediante `terraform_remote_state` o variables; esta capa no gestiona ni conoce el estado de esas capas. La eliminación de estos recursos ocurre exclusivamente a través del flujo manual de destrucción de la Ola 5, no dentro de esta capa.

## Requirements

### Requirement 1: Provisión idempotente del grupo de recursos

**Objective:** Como desarrollador del laboratorio, quiero que la capa cree el grupo de recursos de forma reproducible, para que todas las capas posteriores tengan un contenedor de recursos estable en la región objetivo.

#### Acceptance Criteria

1. When se ejecuta `terraform apply` por primera vez, the capa `foundation` shall crear un grupo de recursos con el nombre y la región provistos por variables de entrada.
2. When se ejecuta `terraform apply` sobre un estado donde el grupo de recursos ya existe y coincide con la configuración, the capa `foundation` shall completar sin crear, modificar ni destruir recursos.
3. While el grupo de recursos ya existe en la suscripción, the capa `foundation` shall reflejar ese recurso en su estado sin producir un error de conflicto.
4. The capa `foundation` shall aplicar al grupo de recursos las etiquetas (tags) provistas por variables de entrada, sin definir valores de etiqueta fijos en el código.

### Requirement 2: Registro de la feature de tipo de seguridad estándar

**Objective:** Como desarrollador del laboratorio, quiero que la suscripción tenga habilitado el tipo de seguridad `Standard`, para que la capa `compute` pueda crear la VM H100 sin Trusted Launch.

#### Acceptance Criteria

1. When se ejecuta `terraform apply`, the capa `foundation` shall registrar la feature `UseStandardSecurityType` del namespace `Microsoft.Compute` en la suscripción.
2. When la feature `UseStandardSecurityType` ha sido registrada, the capa `foundation` shall re-registrar el provider `Microsoft.Compute` para propagar la activación de la feature.
3. While la feature `UseStandardSecurityType` ya se encuentra en estado `Registered`, the capa `foundation` shall completar sin volver a solicitar el registro ni producir error.
4. When finaliza un `apply` exitoso, the capa `foundation` shall dejar la feature `UseStandardSecurityType` en estado observable `Registered` en la suscripción.

### Requirement 3: Autenticación remota no interactiva del provider

**Objective:** Como desarrollador del laboratorio, quiero que la capa se autentique contra Azure de forma no interactiva y remota, para que el despliegue no dependa de una sesión interactiva del Azure CLI en el equipo que ejecuta Terraform.

#### Acceptance Criteria

1. The capa `foundation` shall autenticarse contra Azure usando credenciales provistas mediante variables de entrada o de entorno, sin requerir una sesión interactiva iniciada manualmente.
2. The capa `foundation` shall recibir el identificador de la suscripción de Azure como variable de entrada, sin definirlo fijo en el código.
3. If falta alguna credencial requerida para autenticar el provider, then the capa `foundation` shall detener la ejecución con un mensaje de error que identifique el valor faltante, sin crear recursos parciales.

### Requirement 4: Parametrización completa sin valores hardcodeados

**Objective:** Como desarrollador del laboratorio, quiero que ningún valor de entrada esté quemado en el código, para poder reconfigurar y reutilizar la capa sin editar el código declarativo y sin exponer secretos en el repositorio.

#### Acceptance Criteria

1. The capa `foundation` shall declarar todo valor de configuración (identificador de suscripción, nombre del grupo de recursos, región, prefijos de nombrado y etiquetas) como variable de entrada con tipo y descripción.
2. Where una variable de entrada tiene un valor por defecto seguro y no sensible, the capa `foundation` shall permitir omitir ese valor en la configuración del despliegue.
3. The capa `foundation` shall proveer una plantilla de variables de ejemplo, versionada en el repositorio, que documente todas las variables de entrada requeridas sin contener valores reales ni secretos.
4. The capa `foundation` shall obtener los valores reales del despliegue desde un archivo de variables excluido del control de versiones, de modo que ningún secreto ni valor específico del entorno quede registrado en el repositorio.
5. If una variable de entrada requerida no recibe valor y no tiene default, then the capa `foundation` shall detener la ejecución solicitando ese valor, sin aplicar cambios.

### Requirement 5: Exposición de outputs para capas posteriores

**Objective:** Como desarrollador de las capas `networking` y `compute`, quiero que la capa `foundation` exponga los datos base del despliegue, para poder consumirlos sin volver a declararlos.

#### Acceptance Criteria

1. When finaliza un `apply` exitoso, the capa `foundation` shall exponer como outputs el nombre del grupo de recursos, su identificador y la región.
2. The capa `foundation` shall exponer los outputs con nombres estables y descriptivos en `snake_case` para permitir su consumo por las capas posteriores.
3. The capa `foundation` shall exponer únicamente información no sensible en sus outputs.

### Requirement 6: Idempotencia y calidad verificables

**Objective:** Como desarrollador del laboratorio, quiero que la capa sea idempotente y cumpla estándares de calidad de IaC, para confiar en despliegues repetibles y sin efectos secundarios.

#### Acceptance Criteria

1. When se ejecuta `terraform plan` inmediatamente después de un `apply` exitoso y sin cambios de configuración, the capa `foundation` shall reportar cero cambios (crear/modificar/destruir).
2. The capa `foundation` shall pasar la validación estructural de Terraform (`terraform validate`) y el formateo estándar (`terraform fmt`) sin errores.
3. If un recurso gestionado por la capa deja de existir en Azure entre ejecuciones, then the capa `foundation` shall reconciliar el estado recreándolo en el siguiente `apply` sin intervención manual.
4. The capa `foundation` shall mantener el código de infraestructura separado de los valores de configuración, siguiendo las convenciones de nombrado de archivos y variables definidas en el steering del proyecto.
