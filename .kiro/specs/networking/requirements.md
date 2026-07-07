# Requirements Document

## Introduction

La capa `networking` (Ola 2 del roadmap) es la segunda capa de Terraform (`terraform/02-networking/`) del laboratorio de LLMs con Ollama sobre VM GPU H100. Depende de la capa `foundation` (grupo de recursos y región) y provee la red y la seguridad perimetral sobre la que la capa `compute` (Ola 3) desplegará la VM. Su responsabilidad es dejar disponible una red virtual con subred, una IP pública estable para acceso remoto y un grupo de seguridad de red (NSG) que restringe el acceso entrante exclusivamente a la IP pública del desarrollador.

El desarrollador que opera el laboratorio ejecuta esta capa con Terraform de forma remota contra Azure. La capa debe ser idempotente (un segundo `terraform apply` sin cambios de configuración no produce modificaciones) y no debe contener ningún valor de entrada hardcodeado: todo valor configurable (nombres de recursos, espacios de direcciones, IP del desarrollador, puertos, etiquetas) se declara como variable y se provee externamente. La seguridad por defecto es un principio central: el acceso SSH (22) y a la API de Ollama (11434) nunca queda abierto al tráfico público general, ya que Ollama no dispone de autenticación propia y restringir el origen a la IP del desarrollador es la protección mínima.

## Boundary Context

- **In scope**: Consumo de los outputs de la capa `foundation` (nombre del grupo de recursos y región); provisión idempotente de red virtual (VNet) y subred; provisión de una IP pública estática que persiste entre ciclos de encendido/desasignación; provisión de un NSG con reglas que permiten SSH (22) y la API de Ollama (11434) únicamente desde la IP del desarrollador y deniegan el resto; asociación del NSG al ámbito de red para que las reglas se apliquen sin depender de la capa `compute`; exposición de outputs (identificador de subred, IP pública y su identificador, identificador del NSG) para la capa `compute`; parametrización completa vía variables; plantilla de variables versionada.
- **Out of scope**: Creación o registro del grupo de recursos y de features/providers (Ola 1 `foundation`); creación de la VM, la NIC, los discos, la llave SSH y la asociación de la IP/NIC a la VM (Ola 3 `compute`); configuración interna de la VM y de Ollama (Ola 4 `vm-config`); destrucción del laboratorio y documentación de operación (Ola 5 `teardown-docs`).
- **Adjacent expectations**: Esta capa consume los outputs de `foundation` mediante `terraform_remote_state` o variables, y no gestiona ni conoce el estado interno de `foundation`. La capa `compute` consumirá los outputs de esta capa (subred, IP pública y NSG) para crear la NIC de la VM; esta capa no crea la NIC ni la VM. La eliminación de estos recursos ocurre exclusivamente a través del flujo manual de destrucción de la Ola 5.

## Requirements

### Requirement 1: Consumo de la capa foundation

**Objective:** Como desarrollador del laboratorio, quiero que la capa `networking` reutilice los datos base del despliegue producidos por `foundation`, para no volver a declarar el grupo de recursos ni la región y mantener una única fuente de verdad.

#### Acceptance Criteria

1. When se ejecuta `terraform apply`, the capa `networking` shall obtener el nombre del grupo de recursos y la región desde los outputs de la capa `foundation`, sin redeclarar esos recursos.
2. The capa `networking` shall crear todos sus recursos dentro del grupo de recursos y la región provistos por la capa `foundation`.
3. If los outputs de la capa `foundation` no están disponibles o no pueden leerse, then the capa `networking` shall detener la ejecución con un error que identifique la dependencia faltante, sin crear recursos parciales.

### Requirement 2: Provisión idempotente de red virtual y subred

**Objective:** Como desarrollador del laboratorio, quiero que la capa cree una red virtual con una subred de forma reproducible, para que la VM tenga conectividad de red estable dentro de un espacio de direcciones controlado.

#### Acceptance Criteria

1. When se ejecuta `terraform apply` por primera vez, the capa `networking` shall crear una red virtual y una subred usando los espacios de direcciones provistos por variables de entrada.
2. When se ejecuta `terraform apply` sobre un estado donde la red virtual y la subred ya existen y coinciden con la configuración, the capa `networking` shall completar sin crear, modificar ni destruir recursos.
3. The capa `networking` shall nombrar la red virtual y la subred siguiendo las convenciones de nombrado del proyecto, con los valores provistos por variables de entrada.
4. The capa `networking` shall aplicar a los recursos de red las etiquetas (tags) provistas por variables de entrada, sin definir valores de etiqueta fijos en el código.

### Requirement 3: IP pública estática y persistente

**Objective:** Como desarrollador del laboratorio, quiero una IP pública estática para la VM, para acceder por SSH y consumir la API de Ollama sin reconfigurar las herramientas locales tras cada ciclo de apagado/encendido.

#### Acceptance Criteria

1. When se ejecuta `terraform apply`, the capa `networking` shall crear una IP pública con asignación estática.
2. While la VM asociada esté desasignada (`deallocated`) y luego se vuelva a iniciar, the capa `networking` shall mantener el mismo valor de IP pública sin cambios.
3. The capa `networking` shall nombrar la IP pública siguiendo la convención `prefijo-funcion` del proyecto, con el valor provisto por variables de entrada.

### Requirement 4: Grupo de seguridad de red restringido a la IP del desarrollador

**Objective:** Como desarrollador del laboratorio, quiero que solo mi IP pública pueda alcanzar los puertos SSH y de Ollama, para que la VM GPU y la API sin autenticación nunca queden expuestas a internet.

#### Acceptance Criteria

1. When se ejecuta `terraform apply`, the capa `networking` shall crear un grupo de seguridad de red (NSG) con una regla que permite tráfico entrante al puerto 22 (SSH) únicamente desde la IP del desarrollador provista por variable.
2. When se ejecuta `terraform apply`, the capa `networking` shall crear en el NSG una regla que permite tráfico entrante al puerto de la API de Ollama (11434) únicamente desde la IP del desarrollador provista por variable.
3. The capa `networking` shall recibir la IP del desarrollador y los puertos de acceso como variables de entrada, sin definir valores fijos en el código.
4. If la IP del desarrollador no recibe valor, then the capa `networking` shall detener la ejecución solicitando ese valor, sin crear reglas que abran el acceso al público general.
5. The capa `networking` shall asegurar que ninguna regla creada por la capa permita el tráfico entrante a los puertos 22 y 11434 desde orígenes distintos a la IP del desarrollador.
6. The capa `networking` shall asociar el NSG al ámbito de la red de la VM de modo que las reglas se apliquen sin depender de la capa `compute`.

### Requirement 5: Exposición de outputs para la capa compute

**Objective:** Como desarrollador de la capa `compute`, quiero que `networking` exponga los datos de red necesarios, para crear la NIC de la VM sin volver a declarar la subred, la IP pública ni el NSG.

#### Acceptance Criteria

1. When finaliza un `apply` exitoso, the capa `networking` shall exponer como outputs el identificador de la subred, la IP pública (valor y su identificador) y el identificador del NSG.
2. The capa `networking` shall exponer los outputs con nombres estables y descriptivos en `snake_case` para permitir su consumo por la capa `compute`.
3. The capa `networking` shall exponer únicamente información no sensible en sus outputs.

### Requirement 6: Parametrización completa sin valores hardcodeados

**Objective:** Como desarrollador del laboratorio, quiero que ningún valor de entrada esté quemado en el código, para poder reconfigurar y reutilizar la capa sin editar el código declarativo y sin exponer datos del entorno en el repositorio.

#### Acceptance Criteria

1. The capa `networking` shall declarar todo valor de configuración (espacios de direcciones de la red y la subred, nombres de recursos, IP del desarrollador, puertos de acceso, prefijos de nombrado y etiquetas) como variable de entrada con tipo y descripción.
2. Where una variable de entrada tiene un valor por defecto seguro y no sensible, the capa `networking` shall permitir omitir ese valor en la configuración del despliegue.
3. The capa `networking` shall proveer una plantilla de variables de ejemplo, versionada en el repositorio, que documente todas las variables de entrada requeridas sin contener valores reales ni datos específicos del entorno.
4. The capa `networking` shall obtener los valores reales del despliegue desde un archivo de variables excluido del control de versiones, de modo que ningún valor específico del entorno (como la IP del desarrollador) quede registrado en el repositorio.
5. If una variable de entrada requerida no recibe valor y no tiene default, then the capa `networking` shall detener la ejecución solicitando ese valor, sin aplicar cambios.

### Requirement 7: Idempotencia y calidad verificables

**Objective:** Como desarrollador del laboratorio, quiero que la capa sea idempotente y cumpla estándares de calidad de IaC, para confiar en despliegues repetibles y sin efectos secundarios.

#### Acceptance Criteria

1. When se ejecuta `terraform plan` inmediatamente después de un `apply` exitoso y sin cambios de configuración, the capa `networking` shall reportar cero cambios (crear/modificar/destruir).
2. The capa `networking` shall pasar la validación estructural de Terraform (`terraform validate`) y el formateo estándar (`terraform fmt`) sin errores.
3. If un recurso gestionado por la capa deja de existir en Azure entre ejecuciones, then the capa `networking` shall reconciliar el estado recreándolo en el siguiente `apply` sin intervención manual.
4. The capa `networking` shall mantener el código de infraestructura separado de los valores de configuración, siguiendo las convenciones de nombrado de archivos y variables definidas en el steering del proyecto.
