# Mitigación de vulnerabilidades — WordPress Vulnerable Lab

Este directorio documenta la mitigación de los hallazgos reportados en el informe *Evidencia Pentesting WordPress Vulnerable*, elaborado sobre el laboratorio [wordpress-vulnerable-lab](https://github.com/ayinedjimi/wordpress-vulnerable-lab) v2.0.0 (autor: Ayi Nedjimi, licencia MIT).

Cada mitigación sigue el mismo ciclo:

1. Reproducción del hallazgo (estado anterior).
2. Aplicación del cambio.
3. Ejecución de la misma prueba (estado posterior).
4. Documentación del procedimiento y la evidencia.

## Estado de las mitigaciones

| ID | Hallazgo del informe | OWASP | Medida | Estado |
|---|---|---|---|---|
| [M-01](M-01-archivos-sensibles.md) | 2.3 Exposición de archivos sensibles | A05 | Eliminación de archivos del webroot, reglas en Apache, rotación de la credencial de base de datos y de los salts, registro de depuración fuera del webroot | Verificado |
| [M-02](M-02-directory-listing.md) | 2.8 Listado de directorios | A05 | `Options -Indexes` en `.htaccess` y en la configuración del servidor, deshabilitación de `mod_autoindex` | Verificado |
| [M-03](M-03-enumeracion-usuarios.md) | 2.1 Enumeración de usuarios mediante la REST API | A01 | mu-plugin que restringe la REST API de usuarios, los archivos de autor y oEmbed, y desvincula el slug y el nombre público del nombre de acceso | Verificado |
| [M-04](M-04-fuerza-bruta.md) | 2.2 Fuerza bruta mediante XML-RPC | A07 | Bloqueo de XML-RPC, límite de intentos por IP, contraseñas robustas, mensajes de error uniformes y retirada de cabeceras que anuncian el endpoint | Verificado |
| M-05 | 2.5 XSS reflejado en Ninja Forms (CVE-2023-37979) | A03 | Actualización a la versión 3.6.26 o posterior | Pendiente |
| M-06 | 2.6 SQLi ciega en WP Fastest Cache (CVE-2023-6063) | A03 | Actualización a la versión 1.2.2 o posterior | Pendiente |
| M-07 | 2.7 Escalada de privilegios en Ultimate Member (CVE-2023-3460) | A01 | Actualización a la versión 2.6.7 o posterior y auditoría de cuentas | Pendiente |
| M-08 | 2.4 Componentes desactualizados | A06 | Actualización del núcleo, los complementos, PHP y Apache | Pendiente |

## Estructura

```
hardening/
├── README.md        Índice y estado de las mitigaciones
├── M-0X-*.md        Documento de cada mitigación
├── src/             Artefactos desplegados (Dockerfile, docker-compose, configuración de Apache)
├── apply/           Scripts que aplican cada mitigación sobre el laboratorio en ejecución
├── tests/           Scripts de verificación, ejecutados sin cambios antes y después
└── evidencia/       Salidas de las verificaciones antes y después
```

## Requisitos

- Docker Engine con Docker Compose v2.
- `bash`, `curl` y `openssl`.
- Permisos sobre el daemon de Docker.
- Laboratorio instalado con `scripts/install.sh` (contenedores `wpvl-*` en ejecución).

## Procedimiento de verificación

Los comandos se ejecutan desde la raíz del repositorio.

Las mitigaciones se aplican en orden, porque cada una parte del estado que deja la anterior.

```bash
# M-01 - Exposición de archivos sensibles
bash hardening/tests/m01-archivos-sensibles.sh     # Estado anterior
bash hardening/apply/m01-archivos-sensibles.sh     # Aplicación de la mitigación
bash hardening/tests/m01-archivos-sensibles.sh     # Estado posterior

# M-02 - Listado de directorios
bash hardening/tests/m02-directory-listing.sh
bash hardening/apply/m02-directory-listing.sh
bash hardening/tests/m02-directory-listing.sh

# M-03 - Enumeración de usuarios
bash hardening/tests/m03-enumeracion-usuarios.sh
bash hardening/apply/m03-enumeracion-usuarios.sh
bash hardening/tests/m03-enumeracion-usuarios.sh

# M-04 - Fuerza bruta mediante XML-RPC
bash hardening/tests/m04-fuerza-bruta.sh
bash hardening/apply/m04-fuerza-bruta.sh
bash hardening/tests/m04-fuerza-bruta.sh
```

Las mediciones se realizan con el complemento WP Cerber desactivado para reproducir las condiciones del informe (véase la sección *Incidencias del entorno*). A partir de M-04, las contraseñas de las cuentas son aleatorias y se guardan en `.env`; las pruebas las leen mediante `hardening/tests/lib-credenciales.sh`.

Una vez aplicada M-01, el despliegue endurecido se administra con el archivo de Compose de este directorio:

```bash
docker compose --project-directory . -f hardening/src/docker-compose.yml up -d
```

La contraseña de base de datos generada durante M-01 se almacena en `.env`, en la raíz del proyecto, con permisos `600`. Ese archivo está excluido del control de versiones.

### Control de regresión funcional

Además de la prueba específica de cada hallazgo, después de cada mitigación se ejecuta una prueba de humo que comprueba las funciones principales del sitio: portada, entradas, feed RSS, REST API, `admin-ajax.php`, `wp-cron.php`, inicio de sesión, pantallas del panel de administración y ausencia de errores fatales de PHP o Apache.

```bash
bash hardening/tests/smoke.sh
```

## Incidencias del entorno

### Panel de administración inoperativo desde la instalación (Popup Maker 1.18.0)

Durante el control de regresión posterior a M-02 se detectó que todas las pantallas de `/wp-admin/` respondían HTTP 500, aunque el inicio de sesión era correcto. El registro de Apache identificó la causa:

```
PHP Fatal error: Uncaught Error: Call to undefined function wp_get_environment_type()
in /var/www/html/wp-content/plugins/popup-maker/classes/Admin/Notices.php:261
```

La función `wp_get_environment_type()` se incorporó en WordPress 5.5, y el laboratorio ejecuta WordPress 5.3.2. El complemento Popup Maker 1.18.0, instalado por `scripts/install.sh`, requiere una versión del núcleo superior a la disponible y provoca un error fatal en cada página del panel.

| Aspecto | Determinación |
|---|---|
| Origen | Defecto preexistente del laboratorio: incompatibilidad entre la versión del complemento y la del núcleo |
| Relación con M-01 y M-02 | Ninguna. Esas mitigaciones no modifican el núcleo, los complementos ni la configuración de PHP. |
| Alcance | Popup Maker es el único complemento que provoca errores fatales en el panel; desactivado, las pantallas responden 200 y no se registran errores |
| Relación con el informe | Popup Maker no forma parte de los hallazgos reportados. La incompatibilidad es una manifestación del hallazgo 2.4 (componentes desactualizados) |
| Acción | Se desactivó el complemento para restablecer el panel, necesario para reproducir hallazgos que requieren una sesión administrativa (por ejemplo, 2.5). La corrección definitiva, la actualización del núcleo, corresponde a M-08. |

```bash
docker exec -u root wpvl-wordpress php -d memory_limit=512M /usr/local/bin/wp \
  --allow-root --path=/var/www/html plugin deactivate popup-maker
```

### Eliminación de usuarios inoperativa (User Registration 3.0.2)

Durante la verificación de M-03, la eliminación de una cuenta de prueba produjo un error fatal:

```
PHP Fatal error: Uncaught ArgumentCountError: Too few arguments to function
ur_delete_user_files_on_user_delete(), 2 passed ... and exactly 3 expected
in /var/www/html/wp-content/plugins/user-registration/includes/functions-ur-core.php:2659
```

El complemento User Registration 3.0.2 registra una función que espera tres argumentos en la acción `delete_user`. WordPress incorporó el tercer argumento (`$user`) en la versión 5.5, y el laboratorio ejecuta 5.3.2. En consecuencia, eliminar una cuenta desde el panel o mediante WP-CLI falla. Es otra manifestación del hallazgo 2.4 y su corrección definitiva corresponde a M-08. Mientras tanto, las cuentas de prueba se eliminan omitiendo ese complemento:

```bash
docker exec -u root wpvl-wordpress php -d memory_limit=512M /usr/local/bin/wp \
  --allow-root --path=/var/www/html user delete <ID> --yes --skip-plugins=user-registration
```

### Protecciones de WP Cerber en el entorno de verificación

El laboratorio instala y activa WP Cerber 9.5, que bloquea la REST API de usuarios, los archivos de autor y el autor en oEmbed, e incluye bloqueo por intentos fallidos de inicio de sesión. El informe de pentesting documenta respuestas incompatibles con esas protecciones (REST API de usuarios con HTTP 200 en el hallazgo 2.1; unos cincuenta intentos fallidos sin bloqueo en el hallazgo 2.2), lo que indica que el complemento no estaba activo en el entorno evaluado.

Por tres razones, WP Cerber se mantiene **desactivado** durante el trabajo de mitigación y verificación:

1. Reproduce las condiciones del informe.
2. Es a su vez un componente vulnerable (CVE-2024-2697), incluido en el inventario del hallazgo 2.4; su actualización o retirada se decide en M-08.
3. Su bloqueo por IP responde 404 a secuencias de prueba que generan fallos de inicio de sesión (como la de M-04), lo que falsea las mediciones antes/después.

Cada mitigación se diseña de forma independiente de WP Cerber: no depende de que esté activo ni entra en conflicto con él. En M-03, cuya prueba no genera fallos de inicio de sesión, se verificó además que los controles coexisten con el complemento activo.

## Aviso

El laboratorio base es intencionalmente vulnerable. Debe ejecutarse únicamente en un entorno aislado y no exponerse a redes públicas.
