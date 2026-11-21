<?php
/**
 * Plugin Name: M-04 Protección contra fuerza bruta
 * Description: Deshabilita XML-RPC, uniforma los mensajes de error del inicio de
 *              sesión y limita los intentos de autenticación por dirección IP.
 * Version:     1.0.0
 *
 * Mitigación del hallazgo 2.2 del informe de pentesting (OWASP A07:2021,
 * CWE-307: Restricción inadecuada de intentos de autenticación excesivos).
 *
 * Se distribuye como mu-plugin: WordPress lo carga siempre y no puede
 * desactivarse desde el panel de administración.
 */

defined( 'ABSPATH' ) || exit;

/* -------------------------------------------------------------------------
 * 1. Desactivación de XML-RPC
 *
 * El informe explota wp.getUsersBlogs a través de /xmlrpc.php, que no limita
 * los intentos y permite agrupar muchas pruebas con system.multicall. El sitio
 * no utiliza XML-RPC. La vía principal de bloqueo es la regla de Apache
 * (hardening/src/apache/zz-hardening.conf); estos filtros son defensa en
 * profundidad por si esa regla no estuviera presente.
 * ---------------------------------------------------------------------- */

// Desactiva por completo la interfaz XML-RPC.
add_filter( 'xmlrpc_enabled', '__return_false' );

// Elimina los métodos de pingback, usados para enumeración y amplificación.
add_filter(
	'xmlrpc_methods',
	function ( $metodos ) {
		unset( $metodos['pingback.ping'], $metodos['pingback.extensions.getPingbacks'] );
		return $metodos;
	}
);

// Retira la cabecera X-Pingback que anuncia el endpoint.
add_filter(
	'wp_headers',
	function ( $cabeceras ) {
		unset( $cabeceras['X-Pingback'] );
		return $cabeceras;
	}
);

// Retira el enlace RSD (<link rel="EditURI">), que también apunta a xmlrpc.php.
remove_action( 'wp_head', 'rsd_link' );

/* -------------------------------------------------------------------------
 * 2. Mensajes de error uniformes en el inicio de sesión
 *
 * Por defecto WordPress distingue "usuario inexistente" de "contraseña
 * incorrecta", lo que permite confirmar qué nombres de acceso existen
 * (enumeración, relacionada con el hallazgo 2.1). Se sustituye el mensaje de
 * credenciales por uno genérico, idéntico en ambos casos. El mensaje de bloqueo
 * por exceso de intentos (apartado 3) se conserva, porque no revela qué cuentas
 * existen y sí informa al usuario legítimo de por qué no puede entrar.
 * ---------------------------------------------------------------------- */

add_filter(
	'login_errors',
	function ( $mensaje ) {
		if ( ! empty( $GLOBALS['m04_bloqueado'] ) ) {
			return __( 'Error: demasiados intentos fallidos. Intente de nuevo más tarde.' );
		}
		return __( 'Error: las credenciales no son válidas.' );
	}
);

/* -------------------------------------------------------------------------
 * 3. Límite de intentos de autenticación por dirección IP
 *
 * Tras M04_MAX_INTENTOS fallos desde una misma IP dentro de la ventana, se
 * bloquea todo intento de esa IP durante M04_BLOQUEO_SEG, incluso con
 * credenciales correctas. El contador se guarda en un transitorio, que expira
 * solo (no requiere tarea programada).
 * ---------------------------------------------------------------------- */

const M04_MAX_INTENTOS = 5;      // Fallos permitidos dentro de la ventana.
const M04_VENTANA_SEG  = 900;    // Ventana de conteo: 15 minutos.
const M04_BLOQUEO_SEG  = 900;    // Duración del bloqueo: 15 minutos.

/**
 * Dirección IP del cliente. Usa REMOTE_ADDR, que no es falsificable por el
 * cliente. No se consulta X-Forwarded-For porque puede manipularse; detrás de
 * un proxy de confianza se añadiría su tratamiento aquí.
 */
function m04_ip_cliente() {
	$ip = isset( $_SERVER['REMOTE_ADDR'] ) ? $_SERVER['REMOTE_ADDR'] : '0.0.0.0';
	return filter_var( $ip, FILTER_VALIDATE_IP ) ? $ip : '0.0.0.0';
}

function m04_clave_intentos() {
	return 'm04_intentos_' . md5( m04_ip_cliente() );
}

/**
 * Bloquea la autenticación si la IP superó el límite. Se ejecuta con prioridad
 * 30, después de la validación de credenciales del núcleo (prioridad 20), de
 * modo que una contraseña correcta tampoco concede acceso durante el bloqueo.
 */
add_filter(
	'authenticate',
	function ( $usuario ) {
		$registro = get_transient( m04_clave_intentos() );
		if ( is_array( $registro ) && $registro['conteo'] >= M04_MAX_INTENTOS ) {
			// Señala a login_errors que muestre el mensaje de bloqueo.
			$GLOBALS['m04_bloqueado'] = true;
			return new WP_Error(
				'm04_bloqueado',
				__( 'Error: demasiados intentos fallidos. Intente de nuevo más tarde.' )
			);
		}
		return $usuario;
	},
	30
);

/**
 * Registra cada fallo de inicio de sesión y amplía la ventana de bloqueo.
 */
add_action(
	'wp_login_failed',
	function () {
		$clave    = m04_clave_intentos();
		$registro = get_transient( $clave );
		$conteo   = ( is_array( $registro ) ? $registro['conteo'] : 0 ) + 1;

		// Al alcanzar el límite, la expiración pasa a ser la duración del bloqueo.
		$expira = ( $conteo >= M04_MAX_INTENTOS ) ? M04_BLOQUEO_SEG : M04_VENTANA_SEG;
		set_transient( $clave, array( 'conteo' => $conteo ), $expira );
	}
);

/**
 * Reinicia el contador tras un inicio de sesión correcto.
 */
add_action(
	'wp_login',
	function () {
		delete_transient( m04_clave_intentos() );
	}
);
