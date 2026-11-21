# M-02 — Listado de directorios habilitado en el servidor web

Mitigación del hallazgo **2.8** del informe de pentesting: *Listado de Directorios Habilitado en el Servidor Web*.

| Campo | Valor |
|---|---|
| Severidad | Media. No expone secretos de forma directa, pero entrega el inventario completo de archivos y versiones, insumo para el resto de ataques. |
| CWE | CWE-548 (Exposición de información a través del listado de directorios) |
| OWASP | A05:2021 Configuración de seguridad incorrecta |
| STRIDE | Divulgación de información |
| Componentes | Configuración de Apache, `.htaccess` del sitio e imagen Docker (`Dockerfile`) |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

Cuando se solicita un directorio que no contiene un archivo índice (`index.php`, `index.html`), Apache decide qué responder según la opción `Indexes`:

- **Habilitada:** el módulo `mod_autoindex` genera una página *Index of* con el nombre, la fecha y el tamaño de cada archivo.
- **Deshabilitada:** Apache rechaza la solicitud.

En el sitio evaluado, la opción estaba habilitada por tres vías que se refuerzan entre sí:

1. **Configuración base del servidor.** El `apache2.conf` de Debian declara `Options Indexes FollowSymLinks` para `/var/www/`.
2. **`.htaccess` del sitio.** El archivo declara de forma explícita `Options +Indexes +FollowSymLinks`.
3. **Delegación sin restricciones.** `AllowOverride All` permite que cualquier `.htaccess` del sitio, incluidos los que instalan los complementos, active `Indexes` en su directorio.

### Alcance real

El informe documenta el listado del directorio de `wp-statistics`. Se hizo un barrido de todos los directorios del webroot y el alcance es considerablemente mayor:

| Métrica | Valor |
|---|---|
| Directorios en el webroot | 8 979 |
| Directorios sin archivo índice | 7 887 |
| **Directorios con listado expuesto** | **7 854** |

El listado alcanzaba directorios de administración (`/wp-admin/css/`, `/wp-admin/images/`), el árbol completo de los 45 complementos instalados y sus dependencias (`vendor/`). Esto permite identificar con exactitud las versiones de cada componente y localizar archivos que no deberían ser públicos.

## 2. Configuración vulnerable

**`.htaccess` del sitio** (copiado desde `assets/htaccess`):

```apache
# wordpress-vulnerable-lab — intentionally permissive .htaccess.
# Notable misconfigs:
#   - Directory listing on /wp-content/uploads/
...
Options +Indexes +FollowSymLinks
```

**`/etc/apache2/apache2.conf`** (configuración predeterminada de la imagen base):

```apache
<Directory /var/www/>
	Options Indexes FollowSymLinks
	AllowOverride All
	Require all granted
</Directory>
```

**`Dockerfile`, línea 37.** Amplía la delegación a todo el servidor:

```dockerfile
RUN sed -i 's|AllowOverride None|AllowOverride All|g' /etc/apache2/apache2.conf
```

## 3. Mitigación aplicada

### 3.1 Corrección del `.htaccess` del sitio (causa raíz)

`hardening/src/htaccess`, que reemplaza a `assets/htaccess` en la imagen:

```diff
-# wordpress-vulnerable-lab — intentionally permissive .htaccess.
-# Notable misconfigs:
-#   - Directory listing on /wp-content/uploads/
-#   - .git/, .env, dump.sql, *.bak are reachable
-#   - No HSTS / no security headers
+# .htaccess del sitio - versión endurecida.
+#
+# M-02: el listado automático de directorios se desactiva (-Indexes). Una
+# solicitud a un directorio sin archivo índice deja de devolver el inventario
+# de sus archivos.

-Options +Indexes +FollowSymLinks
+Options -Indexes +FollowSymLinks
```

En el sitio en ejecución, el `.htaccess` reside en el volumen persistente y contiene bloques agregados por complementos (LiteSpeed Cache). Por ese motivo se corrigió únicamente la directiva afectada, sin reemplazar el archivo:

```bash
sed -i -E 's/^(\s*Options\s+.*)\+Indexes/\1-Indexes/' /var/www/html/.htaccess
```

**Fundamento.** El prefijo `-` retira la opción `Indexes` para el directorio del sitio y todos sus subdirectorios. Se conserva `+FollowSymLinks`, que el motor de reescritura (`mod_rewrite`) necesita para las URL amigables de WordPress.

### 3.2 Retiro de `Indexes` en la configuración del servidor

`hardening/src/apache/zz-hardening.conf`:

```diff
+<Directory /var/www/>
+    Options -Indexes
+</Directory>
```

**Fundamento.** Esta sección se combina con la de `apache2.conf` y retira `Indexes` del valor predeterminado del servidor. Si el `.htaccess` se pierde o se regenera, el directorio no vuelve al comportamiento inseguro. Se optó por un archivo de configuración propio en lugar de editar `apache2.conf`, para que el cambio sea explícito, auditable y no se pierda en una actualización del paquete de Apache.

### 3.3 Deshabilitación de `mod_autoindex` (bloqueo definitivo)

`hardening/src/Dockerfile`:

```diff
+# M-02: sin mod_autoindex Apache no puede generar listados de directorios,
+# aunque un .htaccess de la aplicación o de un complemento active Indexes.
+RUN a2dismod -f autoindex
```

**Fundamento.** Las dos medidas anteriores dependen de que ningún `.htaccess` vuelva a declarar `+Indexes`. Con `AllowOverride All`, cualquier complemento podría hacerlo en su propio directorio. Para impedirlo se evaluaron dos alternativas:

| Alternativa | Resultado |
|---|---|
| Restringir `AllowOverride` para prohibir la directiva `Options` en `.htaccess` | **Descartada.** El complemento *All-in-One WP Migration* incluye en `wp-content/ai1wm-backups/.htaccess` la línea `Options -Indexes`. Con la directiva prohibida, Apache respondería error 500 en ese directorio. |
| Deshabilitar el módulo que genera los listados | **Adoptada.** `Options` sigue siendo una directiva válida, así que ningún `.htaccess` falla, pero el servidor deja de tener la capacidad de generar listados. |

Antes de deshabilitar el módulo se comprobó que ningún `.htaccess` del sitio usa directivas exclusivas de `mod_autoindex` (`IndexOptions`, `IndexIgnore`) fuera de un bloque `<IfModule>`, ya que esas directivas producirían un error de configuración.

**Efecto en la respuesta.** Sin `mod_autoindex`, una solicitud a un directorio sin índice recibe **HTTP 404** en lugar de 403. Igual que en M-01, esto impide confirmar la existencia del directorio.

## 4. Verificación

La verificación usa el script [`tests/m02-directory-listing.sh`](tests/m02-directory-listing.sh) en dos fases:

- **Fase 1 (caja negra).** Reproduce la prueba de concepto del informe sobre los directorios señalados por WPScan y el pentesting.
- **Fase 2 (caja gris).** Obtiene del contenedor la lista de todos los directorios sin archivo índice y solicita cada uno por HTTP. Las solicitudes se envían por una única conexión persistente, y las que no reciben respuesta válida se reportan por separado en lugar de contarse como protegidas.

### Antes de la mitigación ([`evidencia/m02-antes.txt`](evidencia/m02-antes.txt))

```
== Fase 1: directorios reportados en el pentesting ==
/wp-content/plugins/wp-statistics/                      LISTADO EXPUESTO
/wp-content/plugins/woocommerce/                        LISTADO EXPUESTO
/wp-content/plugins/wp-statistics/assets/               sin listado
/wp-content/plugins/woocommerce/includes/               LISTADO EXPUESTO

== Fase 2: barrido completo del webroot ==
Directorios sin archivo índice    : 7887
Con listado expuesto (HTTP 200)   : 7854
Sin listado (HTTP 403/404)        : 24
Sin respuesta válida (otros/000)  : 9
```

### Después de la mitigación ([`evidencia/m02-despues.txt`](evidencia/m02-despues.txt))

```
== Fase 1: directorios reportados en el pentesting ==
/wp-content/plugins/wp-statistics/                      sin listado
/wp-content/plugins/woocommerce/                        sin listado
/wp-content/plugins/wp-statistics/assets/               sin listado
/wp-content/plugins/woocommerce/includes/               sin listado

== Fase 2: barrido completo del webroot ==
Directorios sin archivo índice    : 7887
Con listado expuesto (HTTP 200)   : 0
Sin listado (HTTP 403/404)        : 7878
Sin respuesta válida (otros/000)  : 9
```

### Análisis de las respuestas distintas de 200

| Respuesta | Cantidad | Explicación |
|---|---|---|
| 302 (antes y después) | 9 | Directorios de prueba de *Really Simple SSL* (`testssl/*`), que redirigen mediante su propio `.htaccess`. No generan listado en ningún caso. |
| 404 (antes) | 24 | Directorios ocultos (`.github/`, `.phpstan/`, `.circleci/`) bloqueados por la regla de M-01. |
| 403 (antes) | 7 | Directorios que los complementos protegen con su propio `.htaccess` (Akismet, LiteSpeed Cache, `uploads/wp-statistics/`). |

### Verificaciones complementarias

| Prueba | Resultado |
|---|---|
| `apache2ctl -t` | `Syntax OK` |
| `apache2ctl -M` | `mod_autoindex` no figura entre los módulos cargados |
| Directiva activa en `.htaccess` | `Options -Indexes +FollowSymLinks` |

### Ausencia de regresiones

| Recurso | Antes | Después |
|---|---|---|
| `/` (página principal) | 200 | 200 |
| `/wp-login.php` | 200 | 200 |
| Inicio de sesión de `admin` | 302 hacia `/wp-admin/` | 302 hacia `/wp-admin/` |
| Archivo estático (`/wp-includes/js/jquery/jquery.js`) | 200 | 200 |
| Prueba de M-01 | 0 de 15 expuestos | 0 de 15 expuestos |

## 5. Riesgo residual y recomendaciones

- **Identificación de versiones por archivos públicos.** Sin el listado, los archivos `readme.txt` y `changelog.txt` de cada complemento siguen siendo accesibles si se conoce su ruta, y permiten identificar versiones (WPScan las detecta por esa vía). Este vector forma parte del hallazgo 2.4 y se atiende en M-08, donde la medida de fondo es actualizar los componentes.
- **`AllowOverride All`.** La delegación amplia a `.htaccess` se mantiene porque WordPress y varios complementos la requieren. En un servidor bajo control total, se recomienda trasladar las reglas de reescritura de WordPress a la configuración del *virtual host* y establecer `AllowOverride None`, lo que además mejora el rendimiento.
- **Archivos índice de cortesía.** WordPress incluye archivos `index.php` vacíos en `wp-content/` y `wp-content/plugins/` como medida histórica contra el listado. Con `mod_autoindex` deshabilitado ya no son necesarios, pero se conservan como defensa adicional.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`src/htaccess`](src/htaccess) | `.htaccess` del sitio con `Options -Indexes` |
| [`src/apache/zz-hardening.conf`](src/apache/zz-hardening.conf) | Retiro de `Indexes` en la configuración del servidor |
| [`src/Dockerfile`](src/Dockerfile) | Uso del `.htaccess` endurecido y deshabilitación de `mod_autoindex` |
| [`apply/m02-directory-listing.sh`](apply/m02-directory-listing.sh) | Aplicación reproducible e idempotente |
| [`tests/m02-directory-listing.sh`](tests/m02-directory-listing.sh) | Verificación antes y después (caja negra y barrido completo) |
