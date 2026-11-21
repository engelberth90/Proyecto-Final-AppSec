# M-03 — Enumeración de usuarios mediante la REST API

Mitigación del hallazgo **2.1** del informe de pentesting: *Enumeración de Usuarios Mediante la REST API*.

| Campo | Valor |
|---|---|
| Severidad | Media. Revela nombres de acceso válidos, incluida la cuenta administrativa, y habilita el ataque de fuerza bruta del hallazgo 2.2. |
| CWE | CWE-200 (Exposición de información sensible a un actor no autorizado), CWE-203 (Discrepancia observable) |
| OWASP | A01:2021 Pérdida de control de acceso |
| STRIDE | Divulgación de información |
| Componentes | Núcleo de WordPress (REST API, archivos de autor, oEmbed, feeds) y datos de las cuentas de usuario |
| Estado | Mitigado y verificado |

---

## 1. Causa raíz

La enumeración resulta de dos condiciones que se combinan:

1. **Interfaces públicas que muestran al autor.** WordPress expone sin autenticación información de las cuentas por varias vías:
   - La REST API (`/wp/v2/users`) devuelve el identificador, el nombre y el *slug* de toda cuenta con contenido publicado.
   - El archivo de autor (`?author=<id>`) existe para **toda** cuenta, tenga o no entradas, y su título muestra el nombre público.
   - La respuesta oEmbed de una entrada incluye `author_name`.
   - El feed RSS incluye `<dc:creator>` con el nombre público del autor.
2. **Slug y nombre público derivados del nombre de acceso.** Al crear una cuenta, WordPress asigna `user_nicename` (slug) y `display_name` (nombre público) a partir de `user_login`. En las tres cuentas del sitio los tres valores eran idénticos:

| ID | user_login | user_nicename | display_name |
|---|---|---|---|
| 1 | admin | admin | admin |
| 2 | editor | editor | editor |
| 3 | subscriber | subscriber | subscriber |

La primera condición pone la información a la vista. La segunda hace que esa información sea, literalmente, el nombre de acceso.

### Alcance real

La prueba de concepto del informe consulta `?rest_route=/wp/v2/users`, que solo lista cuentas con contenido publicado (`admin`). La verificación ampliada encontró **diez respuestas** que revelan nombres de acceso. Entre ellas, `?author=3` revela la cuenta `subscriber`, que no tiene entradas: recorriendo los identificadores 1, 2, 3… un atacante enumera **todas** las cuentas del sitio, no solo las de los autores.

### Discrepancia con el entorno del informe

El laboratorio instala y activa el complemento de seguridad **WP Cerber 9.5**, cuya configuración bloquea la REST API de usuarios (`norestuser`), los archivos de autor (`stopenum`) y el autor en oEmbed (`stopenum_oembed`). En el entorno de esta verificación la REST API respondía 403. En cambio, el informe documenta una respuesta 200 con los datos de los usuarios, y el hallazgo 2.2 documenta unos cincuenta intentos de autenticación fallidos sin bloqueo, algo incompatible con la protección de Cerber contra intentos repetidos. Ambas evidencias indican que en el entorno evaluado Cerber no estaba activo.

Para reproducir las condiciones del informe, la línea base se midió **con WP Cerber desactivado**. La mitigación se diseñó para no depender de ese complemento, por tres razones:

- es un componente de terceros que puede desactivarse desde el panel;
- tiene una vulnerabilidad publicada (CVE-2024-2697) y forma parte del inventario del hallazgo 2.4;
- aun activo, no cubría el feed RSS (`nofeeds = 0`), que seguía revelando `admin`.

## 2. Comportamiento vulnerable

**REST API, sin autenticación** (prueba de concepto del informe):

```http
GET /?rest_route=/wp/v2/users HTTP/1.1

HTTP/1.1 200 OK
[{"id":1,"name":"admin","url":"","description":"","link":"http://localhost:31338/?author=1","slug":"admin", ...}]
```

**Archivo de autor de una cuenta sin entradas:**

```http
GET /?author=3 HTTP/1.1

HTTP/1.1 200 OK
<title>subscriber &#8211; WordPress Vulnerable Lab</title>
```

**oEmbed y feed RSS:**

```
GET /?rest_route=/oembed/1.0/embed&url=.../?p=1   →  "author_name":"admin"
GET /?feed=rss2                                    →  <dc:creator><![CDATA[admin]]></dc:creator>
```

**Núcleo de WordPress** (`wp-includes/user.php`, función `wp_insert_user`; extracto simplificado). Si no se indican explícitamente, el slug y el nombre público toman el valor del nombre de acceso:

```php
if ( empty( $userdata['user_nicename'] ) ) {
	$user_nicename = sanitize_user( $user_login, true );   // slug = nombre de acceso
}
...
if ( empty( $userdata['display_name'] ) ) {
	...
	$display_name = $user_login;                           // nombre público = nombre de acceso
}
```

## 3. Mitigación aplicada

La mitigación se implementa en un *must-use plugin*: [`src/mu-plugins/m03-enumeracion-usuarios.php`](src/mu-plugins/m03-enumeracion-usuarios.php). WordPress carga los archivos de `wp-content/mu-plugins/` en cada solicitud y no permite desactivarlos desde el panel, de modo que el control no depende de la configuración de un complemento ni de las acciones de un administrador.

Se define una capacidad mínima, `edit_posts` (colaborador o superior), para consultar información de otras cuentas. Se eligió esta capacidad y no `list_users` (solo administradores) porque el editor de bloques consulta `/wp/v2/users?who=authors` para poblar el selector de autor; una restricción mayor rompería esa función para editores y autores.

### 3.1 REST API

```php
add_filter( 'rest_pre_dispatch', function ( $resultado, $servidor, $solicitud ) {
	$ruta = untrailingslashit( $solicitud->get_route() );

	if ( ! preg_match( '#^/wp/v2/users(?:/|$)#', $ruta ) ) {
		return $resultado;
	}
	if ( '/wp/v2/users/me' === $ruta && is_user_logged_in() ) {
		return $resultado;
	}
	if ( m03_puede_consultar_usuarios() ) {
		return $resultado;
	}

	return new WP_Error( 'rest_no_route',
		__( 'No route was found matching the URL and request method.' ),
		array( 'status' => 404 ) );
}, 10, 3 );
```

**Fundamento.**

- El filtro `rest_pre_dispatch` se ejecuta después de que WordPress identifica al usuario de la solicitud y antes de invocar el controlador. Interceptar la solicitud en ese punto cubre todas las variantes de la ruta (`/users`, `/users/<id>`, `?search=`, `?context=embed`) con una sola regla.
- La respuesta imita la de una ruta inexistente (`404 rest_no_route`), sin confirmar que el recurso existe y está protegido.
- `/wp/v2/users/me` se conserva para cualquier cuenta autenticada, porque solo devuelve los datos del propio usuario.

### 3.2 Archivos de autor

```php
add_action( 'template_redirect', function () {
	if ( ! is_author() || m03_puede_consultar_usuarios() ) {
		return;
	}
	global $wp_query;
	$wp_query->set_404();
	status_header( 404 );
	nocache_headers();
}, 0 );
```

**Fundamento.** La acción se registra con prioridad 0 para ejecutarse antes de `redirect_canonical` (prioridad 10). Esa función, en sitios con enlaces permanentes, redirige `?author=1` a `/author/<slug>/` y revelaría el slug en la cabecera `Location` aunque la página se bloqueara después. Al marcar la consulta como 404, WordPress carga la plantilla de error y el archivo de autor deja de ser distinguible de una página inexistente.

### 3.3 oEmbed

```php
add_filter( 'oembed_response_data', function ( $datos ) {
	unset( $datos['author_name'], $datos['author_url'] );
	return $datos;
} );
```

**Fundamento.** En la especificación oEmbed, `author_name` y `author_url` son campos opcionales. Retirarlos no afecta la inserción de contenido en sitios de terceros.

### 3.4 Slug y nombre público independientes del nombre de acceso (causa de fondo)

```php
add_filter( 'wp_pre_insert_user_data', function ( $datos, $actualizacion, $id_usuario ) {
	// ... obtención de $login (en actualizaciones no viene en $datos) ...
	if ( 0 === strcasecmp( $datos['user_nicename'], sanitize_title( $login ) ) ) {
		$datos['user_nicename'] = 'u-' . strtolower( wp_generate_password( 10, false, false ) );
	}
	if ( 0 === strcasecmp( $datos['display_name'], $login ) ) {
		$datos['display_name'] = $id_usuario ? sprintf( 'Usuario %d', $id_usuario ) : 'Usuario';
	}
	return $datos;
}, 10, 3 );
```

**Fundamento.** Los controles 3.1 a 3.3 restringen las vías conocidas de enumeración. Este filtro elimina la causa de fondo: aunque surja una nueva vía de exposición del autor (un tema, un complemento, una futura versión del núcleo), lo expuesto ya no es el nombre de acceso.

- El filtro actúa en cada alta y actualización de cuenta, de modo que también protege a las cuentas que se creen en el futuro. Corregir solo las cuentas existentes no sería suficiente, porque WordPress repetiría el comportamiento en cada registro nuevo.
- Solo sustituye valores **iguales** al nombre de acceso; los nombres públicos que un usuario haya personalizado no se modifican.
- El slug se sustituye por un valor aleatorio (`u-` seguido de 10 caracteres), sin relación con el nombre de acceso.
- El apodo (`nickname`), que WordPress también inicializa con el nombre de acceso, se alinea con el nombre público mediante las acciones `user_register` y `profile_update`.

Las cuentas existentes se corrigieron invocando `wp_update_user()` sobre cada una, lo que aplica el mismo filtro:

| ID | user_login | user_nicename (antes → después) | display_name (antes → después) |
|---|---|---|---|
| 1 | admin | admin → u-h0oz35zp3v | admin → Usuario 1 |
| 2 | editor | editor → u-w3mj4barcc | editor → Usuario 2 |
| 3 | subscriber | subscriber → u-dlvxa7ehzr | subscriber → Usuario 3 |

## 4. Verificación

La verificación usa el script [`tests/m03-enumeracion-usuarios.sh`](tests/m03-enumeracion-usuarios.sh), ejecutado sin cambios antes y después de la mitigación. El script obtiene del sitio la lista de nombres de acceso y considera que una respuesta **filtra** si contiene alguno de ellos en un campo que identifique al autor. Evalúa tres perfiles:

1. **Visitante sin autenticación:** la prueba de concepto del informe y sus variantes.
2. **Suscriptor autenticado:** una cuenta de mínimo privilegio no debe poder enumerar a las demás.
3. **Editor y administrador:** controles funcionales que deben conservar su acceso.

### Antes de la mitigación ([`evidencia/m03-antes.txt`](evidencia/m03-antes.txt)), con WP Cerber desactivado

```
== 1. Visitante sin autenticación ==
  REST ?rest_route=/wp/v2/users (PoC del informe)    HTTP 200  FILTRA   "slug":"admin"
  REST /wp/v2/users/1                                HTTP 200  FILTRA   "slug":"admin"
  REST /wp/v2/users?search=a                         HTTP 200  FILTRA   "slug":"admin"
  REST /wp/v2/users?context=embed                    HTTP 200  FILTRA   "slug":"admin"
  Archivo de autor ?author=1                         HTTP 200  FILTRA   <title>admin &#8211;
  Archivo de autor ?author=2                         HTTP 200  FILTRA   <title>editor &#8211;
  Archivo de autor ?author=3                         HTTP 200  FILTRA   <title>subscriber &#8211;
  oEmbed de la entrada 1                             HTTP 200  FILTRA   author_name":"admin"
  Feed RSS (dc:creator)                              HTTP 200  FILTRA   <dc:creator><![CDATA[admin]]>
== 2. Suscriptor autenticado ==
  REST /wp/v2/users como suscriptor                  HTTP 200  FILTRA   "slug":"admin"

Respuestas con fuga (visitante y suscriptor): 10
```

### Después de la mitigación ([`evidencia/m03-despues.txt`](evidencia/m03-despues.txt)), con WP Cerber desactivado

```
== 1. Visitante sin autenticación ==
  REST ?rest_route=/wp/v2/users (PoC del informe)    HTTP 404  sin fuga
  REST /wp/v2/users/1                                HTTP 404  sin fuga
  REST /wp/v2/users?search=a                         HTTP 404  sin fuga
  REST /wp/v2/users?context=embed                    HTTP 404  sin fuga
  Archivo de autor ?author=1                         HTTP 404  sin fuga
  Archivo de autor ?author=2                         HTTP 404  sin fuga
  Archivo de autor ?author=3                         HTTP 404  sin fuga
  oEmbed de la entrada 1                             HTTP 200  sin fuga
  Feed RSS (dc:creator)                              HTTP 200  sin fuga
== 2. Suscriptor autenticado ==
  REST /wp/v2/users como suscriptor                  HTTP 404  sin fuga
== 3. Controles funcionales ==
  Editor: autores para el editor de bloques          HTTP 200
  Administrador: listado de usuarios por REST        HTTP 200
  Administrador: pantalla de usuarios                HTTP 200

Respuestas con fuga (visitante y suscriptor): 0
```

### Verificaciones complementarias

| Prueba | Resultado |
|---|---|
| Alta de una cuenta nueva (`pruebam03b`) | Slug `u-axr1ky86m7`, nombre público y apodo `Usuario 5`. El control actúa sobre cuentas futuras. La cuenta de prueba se eliminó. |
| `/wp/v2/users/me` como suscriptor | HTTP 200 con los datos propios: el perfil del usuario sigue disponible |
| Prueba repetida con WP Cerber **activo** | 0 respuestas con fuga: ambos controles coexisten sin conflicto |
| Prueba de humo (`tests/smoke.sh`) | Todas las comprobaciones pasaron, sin errores fatales de PHP ni de Apache |
| Construcción de la imagen (`src/Dockerfile`) | Correcta; el mu-plugin se incorpora a la imagen |

## 5. Riesgo residual y recomendaciones

- **Mensajes de error del inicio de sesión.** `wp-login.php` responde con mensajes distintos para un usuario inexistente y para una contraseña incorrecta, lo que permite confirmar nombres de acceso. Este vector pertenece a la autenticación y se atiende en M-04 (hallazgo 2.2), junto con la limitación de intentos.
- **Identificador numérico del autor.** La REST API de entradas sigue incluyendo el campo `author` con el identificador numérico. Sin la correspondencia entre identificador y nombre de acceso, ese dato ya no permite enumerar cuentas.
- **Selector de autor con WP Cerber activo.** Con Cerber activo, el editor recibe 403 en `/wp/v2/users?who=authors`, porque la opción `norestuser` del complemento bloquea la ruta para toda cuenta que no sea administrador. Es un efecto de Cerber, no de este control: con Cerber desactivado la consulta responde 200. Se recomienda revisar la configuración de Cerber al evaluarlo en M-08.
- **Nombres de acceso predecibles.** Los nombres `admin`, `editor` y `subscriber` son los primeros que prueba cualquier diccionario. La mitigación impide obtenerlos del sitio, pero no los vuelve impredecibles. Cambiar un nombre de acceso en WordPress requiere crear una cuenta nueva y transferirle el contenido; se documenta como recomendación para un entorno productivo.

## Archivos de esta mitigación

| Archivo | Propósito |
|---|---|
| [`src/mu-plugins/m03-enumeracion-usuarios.php`](src/mu-plugins/m03-enumeracion-usuarios.php) | Controles sobre la REST API, los archivos de autor y oEmbed, y saneamiento del slug y el nombre público |
| [`src/Dockerfile`](src/Dockerfile) | Incorporación de los mu-plugins a la imagen |
| [`apply/m03-enumeracion-usuarios.sh`](apply/m03-enumeracion-usuarios.sh) | Instalación del mu-plugin y corrección de las cuentas existentes |
| [`tests/m03-enumeracion-usuarios.sh`](tests/m03-enumeracion-usuarios.sh) | Verificación antes y después en tres perfiles |
