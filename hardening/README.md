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

## Aviso

El laboratorio base es intencionalmente vulnerable. Debe ejecutarse únicamente en un entorno aislado y no exponerse a redes públicas.
