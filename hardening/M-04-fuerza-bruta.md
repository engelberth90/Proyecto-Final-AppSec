# M-04 — Fuerza bruta de credenciales mediante XML-RPC

Mitigación del hallazgo **2.2** del informe de pentesting: *Fuerza Bruta de Credenciales Mediante XML-RPC*.

| Campo | Valor |
|---|---|
| Severidad | Alta. Permite tomar el control de cuentas, incluida la administrativa. |
| CWE | CWE-307 (Restricción inadecuada de intentos de autenticación excesivos), CWE-521 (Requisitos de contraseña débiles) |
| OWASP | A07:2021 Fallos de identificación y autenticación |
| STRIDE | Suplantación de identidad (Spoofing) |
| Componentes | Interfaz XML-RPC, formulario de inicio de sesión y contraseñas de las cuentas |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

El ataque del informe tiene éxito por la combinación de cuatro condiciones:

1. **XML-RPC habilitado sin límite de intentos.** El archivo `/xmlrpc.php` acepta el método `wp.getUsersBlogs`, que valida usuario y contraseña, y no aplica ningún límite de intentos. El método `system.multicall` permite además agrupar muchas pruebas en una sola petición HTTP, multiplicando la velocidad del ataque.
2. **Sin límite de intentos en el formulario de acceso.** `wp-login.php` tampoco limita los intentos fallidos, de modo que la fuerza bruta es posible también por esa vía.
3. **Contraseñas débiles.** Las cuentas usaban contraseñas triviales (`admin/admin`, `editor/editor`, `subscriber/password123`), presentes en cualquier diccionario.
4. **El endpoint se anuncia.** La cabecera `X-Pingback` y el enlace RSD (`<link rel="EditURI">`) revelan la ubicación de `xmlrpc.php`.

El hallazgo 2.1 (enumeración de usuarios) aporta el nombre de acceso válido; este hallazgo aporta el método para adivinar su contraseña. Por eso M-03 y M-04 son complementarios.

## 2. Comportamiento vulnerable

**XML-RPC procesa autenticación** (vector del informe):

```http
POST /xmlrpc.php
<methodCall><methodName>wp.getUsersBlogs</methodName>
  <params><param><value>admin</value></param>
          <param><value>CONTRASEÑA</value></param></params>
</methodCall>

HTTP/1.1 200 OK   →  con credenciales correctas, <name>isAdmin</name>...
```

**Amplificación con `system.multicall`:** HTTP 200, permite agrupar múltiples intentos.

**El endpoint se anuncia** en las respuestas:

```
X-Pingback: http://localhost:31338/xmlrpc.php
<link rel="EditURI" type="application/rsd+xml" ... href=".../xmlrpc.php?rsd" />
```

**Sin límite de intentos:** diez intentos fallidos consecutivos se procesan sin bloqueo (0 de 10 bloqueados en la verificación).

## 3. Mitigación aplicada

La mitigación combina el bloqueo de XML-RPC, el límite de intentos en el formulario de acceso, el refuerzo de las contraseñas y la ocultación del endpoint. Se implementa en dos artefactos: una regla de Apache ([`src/apache/zz-hardening.conf`](src/apache/zz-hardening.conf)) y un mu-plugin ([`src/mu-plugins/m04-fuerza-bruta.php`](src/mu-plugins/m04-fuerza-bruta.php)).

### 3.1 Bloqueo de XML-RPC

Apache (vía principal):

```apache
RedirectMatch 404 "(?i)^/xmlrpc\.php$"
```

mu-plugin (defensa en profundidad):

```php
add_filter( 'xmlrpc_enabled', '__return_false' );
add_filter( 'xmlrpc_methods', function ( $m ) {
	unset( $m['pingback.ping'], $m['pingback.extensions.getPingbacks'] );
	return $m;
} );
```

**Fundamento.** El sitio no utiliza XML-RPC, de modo que se bloquea por completo. La regla de Apache responde 404 antes de que la petición llegue a PHP, lo que neutraliza el vector del informe y la amplificación con `system.multicall`. El filtro `xmlrpc_enabled` mantiene la protección si en el futuro se retirara la regla de Apache. Se responde 404, y no 403, para no confirmar la existencia del endpoint.

### 3.2 Ocultación del endpoint

```apache
<IfModule mod_headers.c>
    Header unset X-Pingback
    Header always unset X-Pingback
</IfModule>
```

```php
remove_action( 'wp_head', 'rsd_link' );
```

**Fundamento.** La cabecera `X-Pingback` se retira en el servidor porque algunos complementos la añaden directamente, sin pasar por el filtro `wp_headers` de WordPress. Se usan las dos formas de la directiva: `unset` actúa sobre las respuestas correctas (2xx/3xx), donde PHP coloca la cabecera, y `always unset` cubre además las respuestas de error. El enlace RSD se elimina de la cabecera del documento.

### 3.3 Contraseñas robustas

Las contraseñas débiles se sustituyeron por valores aleatorios de 40 caracteres hexadecimales (`openssl rand -hex 20`), aplicados con `wp user update` y almacenados en el archivo `.env` del proyecto (permisos `600`, fuera del webroot y excluido del control de versiones). Las pruebas los leen mediante [`tests/lib-credenciales.sh`](tests/lib-credenciales.sh), de modo que ninguna contraseña queda escrita en los scripts.

**Fundamento.** Aunque el límite de intentos ralentiza la fuerza bruta, una contraseña trivial puede adivinarse en los primeros intentos. Una contraseña de alta entropía hace inviable el ataque por diccionario incluso si el límite se eludiera.

### 3.4 Mensajes de error uniformes

```php
add_filter( 'login_errors', function () {
	if ( ! empty( $GLOBALS['m04_bloqueado'] ) ) {
		return __( 'Error: demasiados intentos fallidos. Intente de nuevo más tarde.' );
	}
	return __( 'Error: las credenciales no son válidas.' );
} );
```

**Fundamento.** Por defecto WordPress distingue "usuario inexistente" de "contraseña incorrecta", lo que permite confirmar qué nombres de acceso existen. El filtro devuelve un mensaje genérico idéntico en ambos casos. Se conserva, en cambio, el mensaje de bloqueo por exceso de intentos, porque no revela qué cuentas existen y sí informa al usuario legítimo del motivo del rechazo.

### 3.5 Límite de intentos por dirección IP

```php
const M04_MAX_INTENTOS = 5;      // Fallos permitidos dentro de la ventana.
const M04_VENTANA_SEG  = 900;    // Ventana de conteo: 15 minutos.
const M04_BLOQUEO_SEG  = 900;    // Duración del bloqueo: 15 minutos.

add_filter( 'authenticate', function ( $usuario ) {
	$registro = get_transient( m04_clave_intentos() );
	if ( is_array( $registro ) && $registro['conteo'] >= M04_MAX_INTENTOS ) {
		$GLOBALS['m04_bloqueado'] = true;
		return new WP_Error( 'm04_bloqueado', __( 'Error: demasiados intentos fallidos...' ) );
	}
	return $usuario;
}, 30 );
```

**Fundamento.** Tras cinco fallos desde una misma IP, todo intento de esa IP se rechaza durante quince minutos, incluso con credenciales correctas. El conteo se guarda en un transitorio, que expira por sí solo sin necesidad de una tarea programada. El filtro `authenticate` se ejecuta con prioridad 30, después de la validación de credenciales del núcleo (prioridad 20), de modo que una contraseña correcta tampoco concede acceso durante el bloqueo. La IP se obtiene de `REMOTE_ADDR`, que el cliente no puede falsificar; no se usa `X-Forwarded-For`, que sí es manipulable.

## 4. Verificación

La verificación usa el script [`tests/m04-fuerza-bruta.sh`](tests/m04-fuerza-bruta.sh), ejecutado antes y después de la mitigación con el complemento WP Cerber desactivado (véase la nota al final de esta sección).

### Antes de la mitigación ([`evidencia/m04-antes.txt`](evidencia/m04-antes.txt))

```
== 1. XML-RPC (vector del informe) ==
  xmlrpc.php -> HTTP 200
  [FALLO] xmlrpc.php procesa peticiones de autenticación (fuerza bruta posible)
  system.multicall -> HTTP 200 (amplificación disponible)
== 2. Divulgación del endpoint ==
  [FALLO] Cabecera X-Pingback presente
  [FALLO] Enlace RSD presente
== 5. Límite de intentos (10 intentos fallidos consecutivos) ==
  Intentos bloqueados: 0 de 10
  [FALLO] No hay límite de intentos (fuerza bruta ilimitada)
```

### Después de la mitigación ([`evidencia/m04-despues.txt`](evidencia/m04-despues.txt))

```
== 1. XML-RPC (vector del informe) ==
  xmlrpc.php -> HTTP 404
  [OK]    xmlrpc.php no procesa peticiones de autenticación
  system.multicall -> HTTP 404 (bloqueado)
== 2. Divulgación del endpoint ==
  [OK]    Cabecera X-Pingback ausente
  [OK]    Enlace RSD ausente
== 3. Mensajes de error del inicio de sesión ==
  Usuario inexistente : Error: las credenciales no son válidas.
  Contraseña errónea  : Error: las credenciales no son válidas.
  [OK]    Los mensajes son idénticos (no permiten enumerar usuarios)
== 4. Inicio de sesión legítimo (antes del bloqueo) ==
  [OK]    Credenciales válidas conceden acceso (302 -> /wp-admin/)
== 5. Límite de intentos (10 intentos fallidos consecutivos) ==
  Bloqueo activado a partir del intento 6
  Intentos bloqueados: 5 de 10
  [OK]    El límite de intentos está activo
== 6. Recuperación tras limpiar el bloqueo ==
  [OK]    Tras limpiar el bloqueo, el acceso legítimo se restablece
```

### Verificaciones complementarias

| Prueba | Resultado |
|---|---|
| Prueba de humo (`tests/smoke.sh`) con las contraseñas nuevas | Todas las comprobaciones pasaron; el administrador accede con la contraseña robusta |
| Regresión M-01 | 0 de 15 rutas expuestas |
| Regresión M-02 | 0 directorios con listado |
| Regresión M-03 | 0 respuestas con fuga |

### Nota sobre WP Cerber

El laboratorio instala y activa WP Cerber 9.5, que también bloquea XML-RPC y los intentos de inicio de sesión. Con Cerber activo, su bloqueo por IP devuelve 404 a toda la secuencia de la prueba, incluidos los intentos legítimos, y falsea la medición. Dado que el informe se realizó evidentemente con Cerber inactivo (documenta XML-RPC operativo y decenas de intentos sin bloqueo), y que Cerber es a su vez un componente vulnerable (CVE-2024-2697, incluido en el hallazgo 2.4), la medición se realiza con el complemento desactivado. Los controles de M-04 son independientes de Cerber: el bloqueo de `xmlrpc.php` y la retirada de cabeceras operan en Apache, y el límite de intentos en un mu-plugin que no puede desactivarse desde el panel.

## 5. Riesgo residual y recomendaciones

- **Fuerza bruta distribuida.** El límite se aplica por dirección IP. Un atacante con muchas IP (una red de equipos comprometidos) podría repartir los intentos y eludir el umbral. Con contraseñas de alta entropía el ataque sigue siendo inviable, pero para una protección mayor se recomienda un segundo factor de autenticación.
- **Bloqueo por agotamiento.** Un atacante puede provocar el bloqueo de una IP legítima generando fallos desde ella. El riesgo es limitado porque el bloqueo expira en quince minutos y el conteo es por IP; para servicios críticos se evalúan listas de confianza o bloqueo por cuenta además de por IP.
- **Componente de seguridad vulnerable.** WP Cerber 9.5 tiene una vulnerabilidad publicada (CVE-2024-2697) y queda deshabilitado durante este trabajo. Su actualización o retirada se trata en M-08.
- **Otros métodos de autenticación.** La mitigación cubre `wp-login.php` y XML-RPC. Si se habilitara la REST API de autenticación por contraseña de aplicación u otro método, debería extenderse el límite de intentos a esa vía.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`src/apache/zz-hardening.conf`](src/apache/zz-hardening.conf) | Bloqueo de `xmlrpc.php` y retirada de la cabecera `X-Pingback` |
| [`src/mu-plugins/m04-fuerza-bruta.php`](src/mu-plugins/m04-fuerza-bruta.php) | Desactivación de XML-RPC, mensajes uniformes y límite de intentos |
| [`apply/m04-fuerza-bruta.sh`](apply/m04-fuerza-bruta.sh) | Instalación, rotación de contraseñas y reconstrucción |
| [`tests/m04-fuerza-bruta.sh`](tests/m04-fuerza-bruta.sh) | Verificación antes y después |
| [`tests/lib-credenciales.sh`](tests/lib-credenciales.sh) | Carga de credenciales de prueba desde `.env` |
