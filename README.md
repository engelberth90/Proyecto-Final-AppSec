<div align="center">

# 🛡️ Proyecto Final — Seguridad en Aplicaciones

### Pentesting, mitigación y re-evaluación de un sitio WordPress vulnerable

**Universidad Mariano Gálvez de Guatemala** · Facultad de Ingeniería en Sistemas de la Información · Programa de Posgrados · 2026

</div>

---

> ⚠️ **Aviso.** El laboratorio base de este proyecto es **intencionalmente vulnerable**. Debe ejecutarse únicamente en un equipo o red aislados y nunca exponerse a Internet.

## 📌 Descripción

El proyecto aplica el ciclo completo de gestión de vulnerabilidades sobre una aplicación web real:

```
🔍 Pentesting  →  📋 Informe de hallazgos  →  🔧 Mitigación  →  ✅ Re-evaluación
```

1. **Pentesting.** Se evaluó un sitio WordPress con componentes y configuraciones vulnerables y se documentaron los hallazgos con su prueba de concepto, su clasificación OWASP Top 10 2021 / STRIDE / CWE y su nivel de riesgo.
2. **Mitigación.** Cada hallazgo se corrigió en su causa raíz, con controles adicionales de defensa en profundidad, y se verificó con la misma prueba antes y después del cambio.
3. **Re-evaluación.** El autor del pentesting repite sus pruebas sobre cada corrección para confirmar que ya no es explotable.

La rama `main` contiene el proyecto **endurecido** (las 8 mitigaciones aplicadas y verificadas). La rama [`Lab-Vulnerable`](../../tree/Lab-Vulnerable) conserva el laboratorio en su **estado vulnerable** original, para poder comparar.

## 🧪 Laboratorio evaluado

El objetivo de las pruebas es [**wordpress-vulnerable-lab v2.0.0**](https://github.com/ayinedjimi/wordpress-vulnerable-lab), un entorno de entrenamiento de código abierto creado por **Ayi Nedjimi** (licencia MIT). Se despliega con Docker Compose e incluye:

| Componente | Estado vulnerable (evaluado) | Estado endurecido (`main`) |
|---|---|---|
| Núcleo | WordPress 5.3.2 | WordPress 7.1.5 |
| Lenguaje | PHP 7.4.4 | PHP 8.3 |
| Servidor web | Apache 2.4.38 | Apache 2.4.65 |
| Base de datos | MySQL 5.7 | MySQL 5.7 |
| Complementos | 45 en versiones con CVE (2019–2025) | Actualizados a su última versión |
| Configuración | Archivos sensibles, listado de directorios, XML-RPC, enumeración de usuarios | Corregida (ver abajo) |
| Servicios auxiliares | phpMyAdmin, Adminer, MailHog, Redis, Memcached | Igual, limitados a `localhost` |

La documentación original del laboratorio se conserva en [`docs/README-lab-original.md`](docs/README-lab-original.md).

## 🔎 Hallazgos y estado de mitigación

| Hallazgo | Vulnerabilidad | OWASP 2021 | Mitigación | Estado |
|---|---|---|---|---|
| 2.1 | Enumeración de usuarios mediante la REST API | A01 | [M-03](hardening/M-03-enumeracion-usuarios.md) | ✅ Mitigado |
| 2.2 | Fuerza bruta de credenciales mediante XML-RPC | A07 | [M-04](hardening/M-04-fuerza-bruta.md) | ✅ Mitigado |
| 2.3 | Exposición de archivos sensibles por mala configuración | A05 | [M-01](hardening/M-01-archivos-sensibles.md) | ✅ Mitigado |
| 2.4 | Uso de componentes desactualizados y vulnerables | A06 | [M-08](hardening/M-08-componentes-desactualizados.md) | ✅ Mitigado |
| 2.5 | XSS reflejado en Ninja Forms (CVE-2023-37979) | A03 | [M-05](hardening/M-05-xss-ninja-forms.md) | ✅ Mitigado |
| 2.6 | Inyección SQL ciega sin autenticación en WP Fastest Cache (CVE-2023-6063) | A03 | [M-06](hardening/M-06-sqli-wp-fastest-cache.md) | ✅ Mitigado |
| 2.7 | Escalada de privilegios sin autenticación en Ultimate Member (CVE-2023-3460) | A01 | [M-07](hardening/M-07-pe-ultimate-member.md) | ✅ Mitigado |
| 2.8 | Listado de directorios habilitado | A05 | [M-02](hardening/M-02-directory-listing.md) | ✅ Mitigado |

El detalle técnico completo de cada mitigación (causa raíz, código vulnerable, cambio aplicado, fundamento y evidencia antes/después) está en [`hardening/`](hardening/README.md).

## 🔧 Cómo se mitigó cada vulnerabilidad (código antes → después)

A continuación, el cambio esencial de cada mitigación. El código completo y la evidencia están en el documento de cada `M-0X`.

<details>
<summary><b>2.3 — Exposición de archivos sensibles (M-01)</b></summary>

**Antes** — la imagen copiaba archivos sensibles al webroot (`Dockerfile`):

```dockerfile
COPY assets/.env              /var/www/html/.env
COPY assets/wp-config.php.bak /var/www/html/wp-config.php.bak
COPY assets/dump.sql          /var/www/html/dump.sql
COPY assets/git-config        /var/www/html/.git/config
```

**Después** — no se copian, y Apache bloquea esa familia de archivos (`hardening/src/apache/zz-hardening.conf`):

```apache
RedirectMatch 404 "(?i)/\.(?!well-known/)"                       # .env, .git/, .htaccess...
RedirectMatch 404 "(?i)\.(bak|backup|old|sql|log|env|ini|conf)$" # respaldos, volcados, logs
```
Además se rotó la contraseña de base de datos expuesta y se regeneraron los *salts*.
</details>

<details>
<summary><b>2.8 — Listado de directorios (M-02)</b></summary>

**Antes** (`.htaccess`): `Options +Indexes +FollowSymLinks`

**Después** — se desactiva el listado y, además, se deshabilita el módulo que lo genera:

```apache
Options -Indexes +FollowSymLinks
```
```dockerfile
RUN a2dismod -f autoindex   # ningún .htaccess puede reactivar los listados
```
</details>

<details>
<summary><b>2.1 — Enumeración de usuarios (M-03)</b></summary>

**Antes** — WordPress exponía la lista de usuarios por la REST API y el slug era el nombre de acceso.

**Después** — mu-plugin que restringe la ruta a cuentas con permisos de edición (`hardening/src/mu-plugins/m03-enumeracion-usuarios.php`):

```php
add_filter( 'rest_pre_dispatch', function ( $resultado, $servidor, $solicitud ) {
    $ruta = untrailingslashit( $solicitud->get_route() );
    if ( preg_match( '#^/wp/v2/users(?:/|$)#', $ruta ) && ! current_user_can( 'edit_posts' ) ) {
        return new WP_Error( 'rest_no_route', __( '...' ), array( 'status' => 404 ) );
    }
    return $resultado;
}, 10, 3 );
```
Y el slug/nombre público se desvinculan del nombre de acceso en cada alta de usuario.
</details>

<details>
<summary><b>2.2 — Fuerza bruta mediante XML-RPC (M-04)</b></summary>

**Antes** — `/xmlrpc.php` procesaba autenticación sin límite de intentos.

**Después** — se bloquea el endpoint en Apache y se añade límite de intentos por IP (mu-plugin):

```apache
RedirectMatch 404 "(?i)^/xmlrpc\.php$"
```
```php
add_filter( 'authenticate', function ( $usuario ) {
    $r = get_transient( m04_clave_intentos() );
    if ( is_array( $r ) && $r['conteo'] >= M04_MAX_INTENTOS ) {
        return new WP_Error( 'm04_bloqueado', __( 'Demasiados intentos fallidos.' ) );
    }
    return $usuario;
}, 30 );
```
Además, contraseñas robustas y mensajes de error uniformes.
</details>

<details>
<summary><b>2.5 — XSS reflejado en Ninja Forms (M-05)</b></summary>

**Antes** (3.6.25) — el parámetro `data` se devolvía sin escapar:

```json
{"data":{"data":"XSSPROBE<img src=x onerror=alert(document.domain)>", ...}}
```

**Después** — actualización a ≥ 3.6.26, que introduce el saneador del proveedor:

```php
public static function preventScriptTriggerInHtmlOutput( string $s ): string {
    foreach ( ['/<\s*script/i','/onload/i','/onerror/i'] as $re )
        if ( preg_match( $re, $s ) ) return htmlspecialchars( $s, ENT_QUOTES );
    return $s;
}
```
Verificado en vivo sobre el núcleo actualizado (ver M-08).
</details>

<details>
<summary><b>2.6 — Inyección SQL ciega en WP Fastest Cache (M-06)</b></summary>

**Antes** (1.2.1) — el valor de la cookie entraba sin sanear en la consulta (`inc/cache.php`):

```php
$username = preg_replace("/^([^\|]+)\|.+/", "$1", $cookie_value);
$res = $wpdb->get_var("SELECT ... ON `wp_users`.`user_login` = \"$username\" AND ...");
```

**Después** (1.2.2) — el proveedor añade `esc_sql()`:

```diff
  if(isset($username) && $username){
+     $username = esc_sql($username);
      $res = $wpdb->get_var("SELECT ... user_login = \"$username\" ...");
```
Verificado en vivo: el payload `SLEEP(2)` deja de inducir retardo (2.25 s → 0.01 s).
</details>

<details>
<summary><b>2.7 — Escalada de privilegios en Ultimate Member (M-07)</b></summary>

**Antes** (2.6.6) — una **lista de bloqueo** de claves de metadatos (incluida `wp_capabilities`) evadible manipulando la clave.

**Después** (≥ 2.6.7) — se sustituye por una **lista blanca** (`includes/core/class-user.php`):

```php
public function is_metakey_banned( $meta_key, $context = '' ) {
    if ( 'submission' === $context
         && ! in_array( $meta_key, UM()->form()->usermeta_whitelist, true ) ) {
        $is_banned = true;   // solo se aceptan las claves permitidas
    }
}
```
</details>

<details>
<summary><b>2.4 — Componentes desactualizados (M-08)</b></summary>

**Antes** (`Dockerfile`): `FROM wordpress:5.3-php7.4-apache` (WordPress 5.3.2, PHP 7.4, Apache 2.4.38).

**Después** — imagen base soportada + actualización de núcleo, complementos y temas, y ocultación de versiones:

```dockerfile
FROM wordpress:php8.3-apache          # PHP 8.3 / Apache 2.4.65
```
```bash
wp core update            # WordPress 5.3.2 -> 7.1.5
wp plugin update --all    # todos los complementos a su última versión
wp plugin delete popup-builder   # retirado de WordPress.org y vulnerable
```
```apache
ServerTokens Prod
ServerSignature Off
Header unset X-Powered-By
```
</details>

## 🗂️ Estructura del repositorio

```
.
├── README.md                 Descripción del proyecto (este archivo)
├── docker-compose.yml        Despliegue del laboratorio base
├── Dockerfile                Imagen del laboratorio base
├── assets/                   Archivos del laboratorio
├── scripts/                  Instalación, verificación y reinicio del laboratorio
├── docs/                     Documentación original del laboratorio
└── hardening/                Trabajo de mitigación
    ├── M-0X-*.md             Documento técnico de cada mitigación
    ├── src/                  Dockerfile, docker-compose, Apache, PHP y mu-plugins endurecidos
    ├── apply/                Scripts que aplican cada mitigación
    ├── tests/                Pruebas de verificación (antes y después)
    └── evidencia/            Resultados de las pruebas
```

## 🚀 Uso

**Requisitos:** Docker Engine con Compose v2, `bash`, `curl` y `openssl` (Linux, WSL2 o macOS).

```bash
git clone git@github.com:engelberth90/Proyecto-Final-AppSec.git
cd Proyecto-Final-AppSec

# 1. Levantar el laboratorio
bash scripts/install.sh

# 2. Comprobar un hallazgo (estado anterior)
bash hardening/tests/m01-archivos-sensibles.sh

# 3. Aplicar la mitigación correspondiente
bash hardening/apply/m01-archivos-sensibles.sh

# 4. Repetir la prueba (estado posterior)
bash hardening/tests/m01-archivos-sensibles.sh
```

> Las mitigaciones se aplican en orden (`m01` … `m08`); **M-08 debe ejecutarse al final** porque actualiza toda la plataforma. El procedimiento completo está en [`hardening/README.md`](hardening/README.md).

| Servicio | URL |
|---|---|
| WordPress | http://localhost:31338 |
| phpMyAdmin | http://localhost:31339 |
| MailHog | http://localhost:31340 |
| Adminer | http://localhost:31341 |

> 💡 Para evaluar el laboratorio **sin ninguna mitigación**, use la rama [`Lab-Vulnerable`](../../tree/Lab-Vulnerable) o la etiqueta `v0-vulnerable`.

## 🌿 Ramas del repositorio

| Rama | Contenido |
|---|---|
| `main` | Proyecto endurecido: laboratorio + las 8 mitigaciones aplicadas y verificadas |
| `Lab-Vulnerable` | Laboratorio en su estado vulnerable original (para comparación / re-evaluación) |
| `fix/m01` … `fix/m08` | Una rama por mitigación, para revisión finding por finding (*pull request*) |

## 👥 Equipo

| Integrante | Correo | Rol |
|---|---|---|
| Daniel Alfonso Ruiz Barrios | druizb3@miumg.edu.gt | Riesgos y documento |
| Roman Romario Alvarado Morales | ralvaradom1@miumg.edu.gt | Arquitectura y DevSecOps |
| Willy Estuardo Valle Rodríguez | wvaller@miumg.edu.gt | Pruebas de penetración |
| Engelberth José Valentín Macario Juárez | emacarioj@miumg.edu.gt | Mitigación de vulnerabilidades |
| Nataly Estefany Morataya Borrayo | nmoratayab@miumg.edu.gt | QA |

## 📄 Créditos y licencia

- Laboratorio base: [wordpress-vulnerable-lab](https://github.com/ayinedjimi/wordpress-vulnerable-lab) © 2026 Ayi Nedjimi, distribuido bajo licencia MIT. Se conserva su historial de commits y su archivo [`LICENSE`](LICENSE).
- El trabajo de mitigación de este repositorio se distribuye bajo la misma licencia MIT.
