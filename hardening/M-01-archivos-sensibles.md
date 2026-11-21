# M-01 — Exposición de archivos sensibles por mala configuración

Mitigación del hallazgo **2.3** del informe de pentesting: *Exposición de Archivos Sensibles por Mala Configuración*.

| Campo | Valor |
|---|---|
| Severidad | Alta. Expone sin autenticación credenciales válidas de la base de datos. |
| CWE | CWE-538 (Inserción de información sensible en un archivo o directorio accesible externamente), CWE-530 (Exposición de archivos de respaldo), CWE-215 (Inserción de información sensible en código de depuración) |
| OWASP | A05:2021 Configuración de seguridad incorrecta |
| STRIDE | Divulgación de información |
| Componentes | Imagen Docker del sitio (`Dockerfile`), configuración de Apache, `wp-config.php` y definición del despliegue (`docker-compose.yml`) |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

El directorio raíz del sitio web (`/var/www/html`) se publica íntegramente: Apache entrega en texto plano el contenido de cualquier archivo ubicado en él que no sea interpretado por PHP. La exposición se origina en la combinación de tres condiciones:

1. **Presencia de archivos sensibles en el webroot.** La imagen del sitio incluye un archivo de variables de entorno (`.env`), un respaldo de la configuración (`wp-config.php.bak`), un volcado de la base de datos (`dump.sql`), metadatos de control de versiones (`.git/`), un archivo de registro (`debug.log`) y herramientas de diagnóstico (`info.php`, `adminer.php`).
2. **Registro de depuración de WordPress dentro del webroot.** Con `WP_DEBUG_LOG = true`, WordPress escribe en `wp-content/debug.log`, ruta accesible públicamente.
3. **Ausencia de controles en el servidor web.** La configuración de Apache no contiene reglas que impidan servir este tipo de archivos.

El caso del respaldo de configuración ilustra el mecanismo. El archivo `wp-config.php` no se divulga porque Apache lo **ejecuta** mediante PHP y el resultado de esa ejecución es vacío. En cambio, `wp-config.php.bak` carece de la extensión `.php`, por lo que Apache lo **entrega como texto** y revela el código fuente completo de la configuración.

**Impacto confirmado.** La contraseña divulgada (`DB_PASSWORD = wordpress`) coincide con la que utiliza el sitio en su `wp-config.php` activo; se trata, por tanto, de una credencial válida. Las llaves contenidas en `wp-config.php.bak` (`lab-fake-auth-key…`) no coinciden con las llaves en uso, que son aleatorias. Pese a ello, se regeneraron conforme a la práctica de rotar todo secreto potencialmente expuesto.

### Alcance adicional identificado

El informe de pentesting documenta cuatro rutas. Al ampliar la prueba de concepto al resto del webroot se identificaron cinco rutas expuestas adicionales:

| Ruta | Información expuesta | Incluida en el informe |
|---|---|---|
| `/.env` | Credenciales de base de datos, claves de AWS y Stripe, DSN de Sentry | Sí |
| `/wp-config.php.bak` | Credenciales de base de datos y llaves de WordPress | Sí |
| `/dump.sql` | Usuarios, correos electrónicos y hashes de contraseñas | Sí |
| `/.git/config` | URL del repositorio de origen | Sí |
| `/.git/HEAD` | Rama activa del repositorio | No |
| `/debug.log` | Rutas internas, consultas SQL y una contraseña SMTP en texto plano | No |
| `/wp-content/debug.log` | Registro real de WordPress: rutas internas y errores de complementos | No |
| `/info.php` | Salida de `phpinfo()`: versiones, módulos, variables de entorno y rutas | No |
| `/adminer.php` | Herramienta de administración de bases de datos accesible vía web | No |

## 2. Código y configuración vulnerables

**`Dockerfile`, líneas 39 a 48.** La imagen copia los archivos sensibles directamente al webroot:

```dockerfile
# Intentional info leak: expose phpinfo + a couple of bait files.
COPY assets/info.php          /var/www/html/info.php
COPY assets/adminer.php       /var/www/html/adminer.php
COPY assets/debug.log         /var/www/html/debug.log
COPY assets/wp-config.php.bak /var/www/html/wp-config.php.bak
COPY assets/dump.sql          /var/www/html/dump.sql
COPY assets/.env              /var/www/html/.env
COPY assets/htaccess           /var/www/html/.htaccess
COPY assets/git-head           /var/www/html/.git/HEAD
COPY assets/git-config         /var/www/html/.git/config
```

**`docker-compose.yml`, servicio `wordpress`.** La credencial de base de datos se define en texto plano dentro del archivo, y la depuración permanece activa con el registro dentro del webroot:

```yaml
      WORDPRESS_DB_PASSWORD: "wordpress"      # Misma credencial divulgada en .env y wp-config.php.bak
      WORDPRESS_DEBUG: "1"
      WORDPRESS_CONFIG_EXTRA: |
        define('WP_DEBUG_LOG', true);          # true: escribe en wp-content/debug.log (ruta pública)
        define('WP_DEBUG_DISPLAY', true);      # Muestra los errores en las páginas del sitio
```

**Configuración de Apache.** Únicamente contiene la regla predeterminada de Debian, que bloquea los archivos `.ht*`. No existe ningún control sobre `.env`, `.git/`, `*.bak`, `*.sql` ni `*.log`.

## 3. Mitigación aplicada

La mitigación se compone de cinco medidas. La primera elimina la causa raíz; las restantes limitan el impacto de una recurrencia o atienden la consecuencia de la exposición, es decir, la credencial divulgada.

### 3.1 Eliminación de los archivos del webroot (causa raíz)

`hardening/src/Dockerfile`:

```diff
-# Intentional info leak: expose phpinfo + a couple of bait files.
-COPY assets/info.php          /var/www/html/info.php
-COPY assets/adminer.php       /var/www/html/adminer.php
-COPY assets/debug.log         /var/www/html/debug.log
-COPY assets/wp-config.php.bak /var/www/html/wp-config.php.bak
-COPY assets/dump.sql          /var/www/html/dump.sql
-COPY assets/.env              /var/www/html/.env
+# M-01: no se copian al webroot archivos de configuración, respaldos, volcados,
+# logs, metadatos de git ni herramientas de diagnóstico (info.php, adminer.php).
+# Lo que no está en el webroot no se puede descargar.
 COPY assets/htaccess           /var/www/html/.htaccess
-COPY assets/git-head           /var/www/html/.git/HEAD
-COPY assets/git-config         /var/www/html/.git/config
```

**Fundamento.** Apache solo puede servir recursos que existen dentro del webroot. Un archivo ausente no tiene URL que lo devuelva, por lo que esta medida constituye el control principal; las siguientes son controles complementarios.

> **Consideración operativa.** El webroot reside en un volumen de Docker (`wp_data`) que persiste entre reconstrucciones de la imagen. La modificación del `Dockerfile` impide que los archivos aparezcan en despliegues nuevos, pero en el volumen existente fue necesario eliminarlos de forma explícita (paso 1 de `apply/m01-archivos-sensibles.sh`).

### 3.2 Reubicación del registro de depuración

`hardening/src/docker-compose.yml`, con el cambio equivalente aplicado al `wp-config.php` activo:

```diff
-      WORDPRESS_DEBUG: "1"
+      # M-01: WORDPRESS_DEBUG eliminado (no se depura en un sitio expuesto).
       WORDPRESS_CONFIG_EXTRA: |
-        define('WP_DEBUG_LOG', true);
-        define('WP_DEBUG_DISPLAY', true);
+        define('WP_DEBUG_LOG', '/var/log/wordpress/debug.log');
+        define('WP_DEBUG_DISPLAY', false);
```

`hardening/src/Dockerfile`:

```diff
+# M-01: el log de depuración de WordPress vive fuera del webroot.
+RUN install -d -o www-data -g www-data -m 0750 /var/log/wordpress
```

**Fundamento.** Desde la versión 5.1, la constante `WP_DEBUG_LOG` admite una ruta de archivo además del valor `true`. Al dirigir el registro a `/var/log/wordpress/`, fuera de `/var/www/html`, el archivo deja de tener una URL asociada. `WP_DEBUG_DISPLAY = false` evita además que los errores se impriman en las páginas. El directorio pertenece a `www-data` con permisos `0750`, de modo que el proceso PHP puede escribir en él y el resto de usuarios del sistema no puede leerlo.

### 3.3 Reglas de bloqueo en Apache (defensa en profundidad)

Archivo nuevo `hardening/src/apache/zz-hardening.conf`, habilitado con `a2enconf`:

```apache
# 1) Cualquier segmento de la ruta que empiece por punto (.env, .git/, .svn/, .htaccess...)
#    Excepción: /.well-known/ (validación ACME/Let's Encrypt, security.txt).
RedirectMatch 404 "(?i)/\.(?!well-known/)"

# 2) Respaldos, volcados de base de datos, logs y archivos temporales de editores.
RedirectMatch 404 "(?i)\.(bak|backup|old|orig|save|swp|swo|tmp|sql|gz|tgz|tar|zip|7z|rar|log|ini|conf|dist|env)$"
RedirectMatch 404 "~$"

# 3) Archivos que nunca deben solicitarse por HTTP.
RedirectMatch 404 "(?i)^/(wp-config\.php|info\.php|phpinfo\.php|adminer\.php|test\.php)$"
```

**Fundamento.**

- **Contención del error humano.** Si un archivo como `backup.sql` o `wp-config.php~` (copia de seguridad automática de los editores nano y vim) se deposita nuevamente en el webroot, la regla impide servirlo aunque el archivo exista.
- **Bloqueo por patrón y no por nombre exacto.** Bloquear únicamente `/.env` permitiría el acceso a `/.env.backup` o a `/.git/HEAD`. Las expresiones regulares cubren familias completas de archivos, sin distinción de mayúsculas y en cualquier directorio.
- **Ubicación en la configuración del servidor y no en `.htaccess`.** WordPress y complementos como LiteSpeed Cache reescriben `.htaccess`; en este entorno dicho archivo ya había sido modificado por un complemento. La configuración del servidor no puede ser alterada por la aplicación ni por un usuario de WordPress, y no depende de la directiva `AllowOverride`.
- **Respuesta 404 en lugar de 403.** Un código 403 confirma la existencia del recurso. Con 404, un atacante no puede distinguir un archivo bloqueado de uno inexistente.

### 3.4 Rotación de la credencial expuesta

`hardening/src/docker-compose.yml`:

```diff
-      MYSQL_PASSWORD: "wordpress"
+      # M-01: credencial rotada; se lee de ./.env (fuera del webroot, permisos 600).
+      MYSQL_PASSWORD: "${WP_DB_PASSWORD:?Define WP_DB_PASSWORD en .env}"
 ...
-      WORDPRESS_DB_PASSWORD: "wordpress"
+      # M-01: credencial rotada (la anterior quedó expuesta en .env y wp-config.php.bak).
+      WORDPRESS_DB_PASSWORD: "${WP_DB_PASSWORD:?Define WP_DB_PASSWORD en .env}"
```

Sentencia aplicada en MySQL:

```sql
ALTER USER 'wordpress'@'%' IDENTIFIED BY '<48 caracteres hexadecimales aleatorios>';
```

**Fundamento.** La eliminación de un archivo no revoca el secreto que contenía: cualquier tercero que lo haya descargado conserva una credencial válida. En consecuencia:

- La contraseña nueva se genera con `openssl rand -hex 24` y se aplica en MySQL (`ALTER USER`) y en `wp-config.php`.
- Se almacena en el archivo `.env` del directorio del proyecto, con permisos `600`. Ese archivo lo lee Docker Compose; no se encuentra en el webroot, está excluido del control de versiones (`.gitignore`) y del contexto de construcción de la imagen (`.dockerignore`).
- La sintaxis `${VARIABLE:?mensaje}` provoca que el despliegue falle si la variable no está definida, en lugar de iniciar con una contraseña vacía o predeterminada.

> **Consideración operativa.** El script de inicio de la imagen oficial de WordPress reescribe `DB_PASSWORD` a partir de las variables del despliegue en cada arranque. Si la contraseña se hubiera cambiado únicamente en MySQL, el sitio perdería la conexión con la base de datos en el siguiente reinicio. Por ello el cambio se aplica también en `docker-compose.yml`.

### 3.5 Regeneración de llaves y salts

```bash
wp config shuffle-salts
```

**Fundamento.** Las llaves y salts de WordPress firman las cookies de sesión. Su divulgación permitiría a un atacante fabricar una cookie de administrador válida sin conocer la contraseña. Aunque las llaves divulgadas no coincidían con las vigentes, la rotación tiene un costo operativo mínimo e invalida cualquier sesión potencialmente comprometida.

## 4. Verificación

La verificación utiliza el mismo script, [`tests/m01-archivos-sensibles.sh`](tests/m01-archivos-sensibles.sh), ejecutado antes y después de la mitigación. El script reproduce la prueba de concepto del informe (solicitudes `curl` sin credenciales) sobre quince rutas: las cuatro reportadas, las cinco adicionales y seis variantes que un atacante probaría ante un bloqueo por nombre exacto.

### Antes de la mitigación ([`evidencia/m01-antes.txt`](evidencia/m01-antes.txt))

```
RUTA                       HTTP   RESULTADO
/.env                      200    EXPUESTO
/wp-config.php.bak         200    EXPUESTO
/dump.sql                  200    EXPUESTO
/.git/config               200    EXPUESTO
/.git/HEAD                 200    EXPUESTO
/debug.log                 200    EXPUESTO
/wp-content/debug.log      200    EXPUESTO
/info.php                  200    EXPUESTO
/adminer.php               200    EXPUESTO
...
Total expuestos: 9 de 15
```

### Después de la mitigación ([`evidencia/m01-despues.txt`](evidencia/m01-despues.txt))

```
RUTA                       HTTP   RESULTADO
/.env                      404    bloqueado/no existe
/wp-config.php.bak         404    bloqueado/no existe
/dump.sql                  404    bloqueado/no existe
/.git/config               404    bloqueado/no existe
/.git/HEAD                 404    bloqueado/no existe
/debug.log                 404    bloqueado/no existe
/wp-content/debug.log      404    bloqueado/no existe
/info.php                  404    bloqueado/no existe
/adminer.php               404    bloqueado/no existe
/.htaccess                 404    bloqueado/no existe
/wp-config.php~            404    bloqueado/no existe
/wp-config.php.old         404    bloqueado/no existe
/wp-config.php.save        404    bloqueado/no existe
/backup.sql.gz             404    bloqueado/no existe
/.env.backup               404    bloqueado/no existe
Total expuestos: 0 de 15
```

### Verificaciones complementarias

| Prueba | Resultado |
|---|---|
| Conexión a MySQL con la credencial divulgada (`wordpress` / `wordpress`) | `ERROR 1045: Access denied`. La credencial divulgada quedó revocada. |
| Conexión a MySQL con la credencial nueva | Conexión establecida |
| Configuración de depuración en `wp-config.php` | `WP_DEBUG = false`, `WP_DEBUG_DISPLAY = false`, `WP_DEBUG_LOG = '/var/log/wordpress/debug.log'` |
| Persistencia | El contenedor se reconstruyó a partir de `hardening/src/Dockerfile` y la verificación posterior se ejecutó sobre la imagen resultante |

### Ausencia de regresiones

| Recurso | Antes | Después |
|---|---|---|
| `/` (página principal) | 200 | 200 |
| `/wp-login.php` | 200 | 200 |
| Inicio de sesión de `admin` (POST a `wp-login.php`) | — | 302 hacia `/wp-admin/` |
| `/wp-content/plugins/wp-statistics/readme.txt` | 200 | 200 |

## 5. Riesgo residual y recomendaciones

- **Secretos divulgados.** Todo secreto expuesto debe considerarse comprometido. En un entorno productivo corresponde además rotar las claves de AWS y Stripe y el DSN de Sentry contenidos en `.env` (en este laboratorio son valores ficticios con el prefijo `LAB-FAKE`) y forzar el cambio de contraseña de los usuarios cuyos hashes figuraban en `dump.sql` (en este laboratorio, también ficticios). La debilidad de la contraseña de la cuenta `admin` se atiende en la mitigación del hallazgo 2.2.
- **Listado de directorios.** El `.htaccess` del sitio conserva la directiva `Options +Indexes`. Su corrección corresponde a M-02 (hallazgo 2.8).
- **Servicios auxiliares fuera del alcance del informe.** MySQL mantiene la cuenta `root` con contraseña `root`, y phpMyAdmin y Adminer inician sesión automáticamente como `root`. Los puertos de estos servicios están limitados a la interfaz de loopback (`127.0.0.1`), por lo que no son alcanzables desde la red; en un entorno productivo no deberían desplegarse junto al sitio.
- **Impacto funcional de la regla de extensiones.** El bloqueo de `.zip`, `.gz` y `.log` en todo el sitio impediría servir descargas legítimas con esas extensiones, por ejemplo desde `wp-content/uploads/`. Si el negocio lo requiere, la regla 2 puede acotarse al directorio raíz o excluir el directorio de descargas.
- **Control en el proceso de despliegue.** La causa de fondo es la inclusión de archivos indebidos en el artefacto desplegado. Se incorporó un `.dockerignore` que excluye `.env` y `.git` del contexto de construcción. En un flujo de integración continua se recomienda además un análisis de secretos (por ejemplo, `gitleaks`) que detenga la construcción ante archivos `.env`, `*.sql` o `*.bak`.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`src/Dockerfile`](src/Dockerfile) | Imagen sin archivos sensibles, con reglas de Apache y directorio de registro fuera del webroot |
| [`src/docker-compose.yml`](src/docker-compose.yml) | Credencial parametrizada, depuración desactivada y puertos limitados a loopback |
| [`src/apache/zz-hardening.conf`](src/apache/zz-hardening.conf) | Reglas de bloqueo en Apache |
| [`../.dockerignore`](../.dockerignore) | Exclusión de secretos y metadatos del contexto de construcción |
| [`apply/m01-archivos-sensibles.sh`](apply/m01-archivos-sensibles.sh) | Aplicación reproducible e idempotente de la mitigación |
| [`tests/m01-archivos-sensibles.sh`](tests/m01-archivos-sensibles.sh) | Verificación antes y después |
