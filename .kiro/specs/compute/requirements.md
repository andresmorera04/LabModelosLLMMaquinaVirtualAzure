# Requirements Document

## Introduction

La capa `compute` (Ola 3 del roadmap) es la tercera capa de Terraform (`terraform/03-compute/`) del laboratorio de LLMs con Ollama sobre VM GPU H100. Depende de la capa `foundation` (grupo de recursos y región) y de la capa `networking` (subred, IP pública y NSG). Su responsabilidad es provisionar la máquina virtual GPU con su interfaz de red, disco del sistema operativo, autenticación SSH y aceptación de los términos de la imagen del Marketplace, dejando la VM lista para recibir la configuración de software en la fase posterior.

El desarrollador que opera el laboratorio ejecuta esta capa con Terraform de forma remota contra Azure. La capa debe ser idempotente (un segundo `terraform apply` sin cambios de configuración no produce modificaciones) y no debe contener ningún valor de entrada hardcodeado: todo valor configurable (tamaño de VM, imagen, tamaño de disco, nombre de usuario administrador, ruta de llave SSH, nombres de recursos, etiquetas) se declara como variable y se provee externamente.

## Boundary Context

- **In scope**: Consumo de outputs de las capas `foundation` (nombre del grupo de recursos, región) y `networking` (identificador de subred, identificador de IP pública); provisión idempotente de la interfaz de red (NIC) asociada a la subred e IP pública de la capa `networking`; aceptación idempotente de los términos de la imagen Marketplace; provisión idempotente de la VM GPU con tipo de seguridad `Standard`, disco OS y autenticación SSH por llave pública; exposición de outputs (nombre de la VM, IP pública, usuario administrador) para la fase de configuración; parametrización completa vía variables; plantilla de variables versionada.
- **Out of scope**: Creación o registro del grupo de recursos y de features/providers (Ola 1 `foundation`); creación de la red virtual, subred, IP pública y NSG (Ola 2 `networking`); configuración interna de la VM, instalación de Ollama, montaje de NVMe y descarga de modelos (Ola 4 `vm-config`); destrucción del laboratorio y documentación de operación (Ola 5 `teardown-docs`).
- **Adjacent expectations**: Esta capa consume los outputs de `foundation` y `networking` mediante `terraform_remote_state` o variables, y no gestiona ni conoce el estado interno de esas capas. La fase de configuración (Ola 4 `vm-config`) utilizará la IP pública y el usuario administrador expuestos por esta capa para conectarse vía SSH y ejecutar los scripts de configuración. La eliminación de estos recursos ocurre exclusivamente a través del flujo manual de destrucción de la Ola 5.

## Requirements

### Requirement 1: Consumo de las capas foundation y networking

**Objective:** Como desarrollador del laboratorio, quiero que la capa `compute` reutilice los datos base del despliegue producidos por `foundation` y los recursos de red producidos por `networking`, para mantener una única fuente de verdad y no redeclarar recursos ya existentes.

#### Acceptance Criteria

1. When se ejecuta `terraform apply`, the capa `compute` shall obtener el nombre del grupo de recursos y la región desde los outputs de la capa `foundation`, sin redeclarar esos recursos.
2. When se ejecuta `terraform apply`, the capa `compute` shall obtener el identificador de la subred y el identificador de la IP pública desde los outputs de la capa `networking`, sin redeclarar esos recursos.
3. The capa `compute` shall crear todos sus recursos dentro del grupo de recursos y la región provistos por la capa `foundation`.
4. If los outputs de las capas `foundation` o `networking` no están disponibles o no pueden leerse, then the capa `compute` shall detener la ejecución con un error que identifique la dependencia faltante, sin crear recursos parciales.

### Requirement 2: Provisión de la interfaz de red

**Objective:** Como desarrollador del laboratorio, quiero que la capa cree una interfaz de red (NIC) conectada a la subred y asociada a la IP pública de la capa `networking`, para que la VM tenga conectividad de red y sea alcanzable por su IP pública estática.

#### Acceptance Criteria

1. When se ejecuta `terraform apply` por primera vez, the capa `compute` shall crear una interfaz de red (NIC) asociada a la subred provista por la capa `networking`.
2. When se ejecuta `terraform apply`, the capa `compute` shall asociar la IP pública provista por la capa `networking` a la NIC, de modo que la VM sea accesible desde la IP estática ya creada.
3. The capa `compute` shall nombrar la NIC siguiendo la convención `prefijo-funcion` del proyecto, con el valor provisto por variables de entrada.
4. The capa `compute` shall aplicar a la NIC las etiquetas (tags) provistas por variables de entrada, sin definir valores de etiqueta fijos en el código.

### Requirement 3: Aceptación de términos de la imagen Marketplace

**Objective:** Como desarrollador del laboratorio, quiero que los términos legales de la imagen Marketplace se acepten de forma automatizada e idempotente, para que la creación de la VM no falle por términos pendientes de aceptación y no requiera intervención manual.

#### Acceptance Criteria

1. When se ejecuta `terraform apply`, the capa `compute` shall aceptar los términos de la imagen Marketplace correspondientes al publisher, offer y SKU provistos por variables de entrada.
2. While los términos de la imagen Marketplace ya se encuentran aceptados para la suscripción, the capa `compute` shall completar sin volver a solicitar la aceptación ni producir error.

### Requirement 4: Provisión de la VM GPU

**Objective:** Como desarrollador del laboratorio, quiero que la capa provisione una máquina virtual GPU con la imagen HPC preconfigurada, para disponer de hardware con GPU NVIDIA H100 y drivers preinstalados sobre los cuales instalar y ejecutar Ollama con modelos LLM de alta capacidad.

#### Acceptance Criteria

1. When se ejecuta `terraform apply` por primera vez, the capa `compute` shall crear una máquina virtual con el tamaño (size), la imagen del sistema operativo (publisher, offer, SKU, version) y el tipo de seguridad provistos por variables de entrada.
2. When se ejecuta `terraform apply`, the capa `compute` shall crear un disco del sistema operativo para la VM con el tamaño y el tipo de almacenamiento provistos por variables de entrada.
3. The capa `compute` shall asociar la NIC creada en el Requirement 2 a la VM, de modo que la VM tenga conectividad de red al iniciar.
4. When se ejecuta `terraform apply` sobre un estado donde la VM ya existe y coincide con la configuración, the capa `compute` shall completar sin crear, modificar ni destruir la VM.
5. The capa `compute` shall nombrar la VM siguiendo la convención `prefijo-funcion` del proyecto, con el valor provisto por variables de entrada.
6. The capa `compute` shall aplicar a la VM las etiquetas (tags) provistas por variables de entrada, sin definir valores de etiqueta fijos en el código.
7. The capa `compute` shall configurar la VM con tipo de seguridad `Standard` (no Trusted Launch), dependiendo de la feature `UseStandardSecurityType` registrada por la capa `foundation`.

### Requirement 5: Autenticación SSH por llave pública

**Objective:** Como desarrollador del laboratorio, quiero que la VM se configure con autenticación SSH por llave pública y un usuario administrador definido por variable, para conectarme de forma segura sin contraseñas y ejecutar los scripts de configuración posteriores.

#### Acceptance Criteria

1. The capa `compute` shall configurar la VM con un usuario administrador cuyo nombre se provee por variable de entrada.
2. The capa `compute` shall configurar la VM con autenticación SSH por llave pública, obteniendo la ruta del archivo de llave pública desde una variable de entrada.
3. The capa `compute` shall deshabilitar la autenticación por contraseña en la VM, permitiendo únicamente el acceso por llave SSH.
4. If la ruta de la llave pública SSH provista no es válida o el archivo no puede leerse, then the capa `compute` shall detener la ejecución con un error que identifique el problema, sin crear la VM con un estado de autenticación incompleto.

### Requirement 6: Exposición de outputs para la fase de configuración

**Objective:** Como desarrollador que opera el laboratorio, quiero que la capa `compute` exponga los datos necesarios para conectarse a la VM, para poder ejecutar los scripts de configuración y las operaciones diarias sin consultar la consola de Azure.

#### Acceptance Criteria

1. When finaliza un `apply` exitoso, the capa `compute` shall exponer como outputs el nombre de la VM, la dirección IP pública y el nombre del usuario administrador.
2. The capa `compute` shall exponer los outputs con nombres estables y descriptivos en `snake_case` para permitir su consumo por scripts de configuración y operación.
3. The capa `compute` shall exponer únicamente información no sensible en sus outputs.

### Requirement 7: Parametrización completa sin valores hardcodeados

**Objective:** Como desarrollador del laboratorio, quiero que ningún valor de entrada esté quemado en el código, para poder reconfigurar y reutilizar la capa sin editar el código declarativo y sin exponer datos del entorno en el repositorio.

#### Acceptance Criteria

1. The capa `compute` shall declarar todo valor de configuración (tamaño de VM, imagen del sistema operativo, tamaño y tipo de disco, nombre de usuario administrador, ruta de llave SSH, nombres de recursos y etiquetas) como variable de entrada con tipo y descripción.
2. Where una variable de entrada tiene un valor por defecto seguro y no sensible, the capa `compute` shall permitir omitir ese valor en la configuración del despliegue.
3. The capa `compute` shall proveer una plantilla de variables de ejemplo, versionada en el repositorio, que documente todas las variables de entrada requeridas sin contener valores reales ni datos específicos del entorno.
4. The capa `compute` shall obtener los valores reales del despliegue desde un archivo de variables excluido del control de versiones, de modo que ningún valor específico del entorno quede registrado en el repositorio.
5. If una variable de entrada requerida no recibe valor y no tiene default, then the capa `compute` shall detener la ejecución solicitando ese valor, sin aplicar cambios.

### Requirement 8: Idempotencia y calidad verificables

**Objective:** Como desarrollador del laboratorio, quiero que la capa sea idempotente y cumpla estándares de calidad de IaC, para confiar en despliegues repetibles y sin efectos secundarios.

#### Acceptance Criteria

1. When se ejecuta `terraform plan` inmediatamente después de un `apply` exitoso y sin cambios de configuración, the capa `compute` shall reportar cero cambios (crear/modificar/destruir).
2. The capa `compute` shall pasar la validación estructural de Terraform (`terraform validate`) y el formateo estándar (`terraform fmt`) sin errores.
3. If un recurso gestionado por la capa deja de existir en Azure entre ejecuciones, then the capa `compute` shall reconciliar el estado recreándolo en el siguiente `apply` sin intervención manual.
4. The capa `compute` shall mantener el código de infraestructura separado de los valores de configuración, siguiendo las convenciones de nombrado de archivos y variables definidas en el steering del proyecto.
