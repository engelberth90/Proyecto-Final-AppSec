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
| M-03 | 2.1 Enumeración de usuarios mediante la REST API | A01 | Restricción de `/wp/v2/users` y de `?author=` a usuarios autenticados | Pendiente |
| M-04 | 2.2 Fuerza bruta mediante XML-RPC | A07 | Desactivación de XML-RPC, contraseñas robustas y limitación de intentos | Pendiente |
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
```

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

## Aviso

El laboratorio base es intencionalmente vulnerable. Debe ejecutarse únicamente en un entorno aislado y no exponerse a redes públicas.
