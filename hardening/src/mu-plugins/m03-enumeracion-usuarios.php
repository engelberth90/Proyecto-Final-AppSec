<?php
/**
 * Plugin Name: M-03 Prevención de enumeración de usuarios
 * Description: Impide que visitantes y cuentas sin permisos de edición obtengan
 *              nombres de usuario a través de la REST API, los archivos de autor
 *              y oEmbed, y evita que el slug o el nombre público de una cuenta
 *              coincidan con su nombre de acceso.
 * Version:     1.0.0
 *
 * Mitigación del hallazgo 2.1 del informe de pentesting (OWASP A01:2021, CWE-200).
 *
 * Se distribuye como mu-plugin (wp-content/mu-plugins/): WordPress lo carga
 * siempre y no puede desactivarse desde el panel de administración.
 */

defined( 'ABSPATH' ) || exit;

/**
 * Capacidad mínima para consultar información de otras cuentas.
 *
 * Se usa edit_posts (colaborador o superior) porque el editor de bloques
 * consulta /wp/v2/users?who=authors para poblar el selector de autor. Los
 * visitantes y los suscriptores no disponen de esta capacidad.
 */
const M03_CAPACIDAD_MINIMA = 'edit_posts';

/**
 * Indica si la solicitud actual proviene de una cuenta autorizada a consultar
 * información de otros usuarios.
 */
function m03_puede_consultar_usuarios() {
	return current_user_can( M03_CAPACIDAD_MINIMA );
}

/**
 * 1. REST API: /wp/v2/users y /wp/v2/users/<id>.
 *
 * El controlador de usuarios de WordPress expone sin autenticación el
 * identificador, el nombre y el slug de toda cuenta con contenido publicado.
 * El slug coincide por defecto con el nombre de acceso.
 *
 * Se intercepta la solicitud antes de despachar la ruta y se responde como si
 * la ruta no existiera (404 rest_no_route), sin confirmar que el recurso está
 * protegido. Se conserva /wp/v2/users/me para que toda cuenta autenticada
 * pueda consultar su propio perfil.
 */
add_filter(
	'rest_pre_dispatch',
	function ( $resultado, $servidor, $solicitud ) {
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

		return new WP_Error(
			'rest_no_route',
			__( 'No route was found matching the URL and request method.' ),
			array( 'status' => 404 )
		);
	},
	10,
	3
);

/**
 * 2. Archivos de autor: ?author=<id> y ?author_name=<slug>.
 *
 * Cada cuenta tiene un archivo de autor cuyo título muestra el nombre público,
 * aunque la cuenta no tenga entradas publicadas. Recorrer ?author=1, 2, 3...
 * permite enumerar todas las cuentas del sitio.
 *
 * Para quien no dispone de la capacidad mínima, la consulta se convierte en un
 * 404 antes de que actúe la redirección canónica de WordPress (prioridad 10),
 * que en sitios con enlaces permanentes redirige a /author/<slug>/.
 */
add_action(
	'template_redirect',
	function () {
		if ( ! is_author() || m03_puede_consultar_usuarios() ) {
			return;
		}
		global $wp_query;
		$wp_query->set_404();
		status_header( 404 );
		nocache_headers();
	},
	0
);

/**
 * 3. oEmbed: /oembed/1.0/embed.
 *
 * La respuesta oEmbed de una entrada incluye author_name y author_url. Ambos
 * campos son opcionales según la especificación oEmbed y se retiran.
 */
add_filter(
	'oembed_response_data',
	function ( $datos ) {
		unset( $datos['author_name'], $datos['author_url'] );
		return $datos;
	}
);

/**
 * 4. Causa de fondo: slug y nombre público derivados del nombre de acceso.
 *
 * Al crear una cuenta, WordPress asigna user_nicename (slug usado en URL y en
 * la REST API) y display_name (nombre mostrado en entradas, feeds y archivos
 * de autor) a partir de user_login. Cualquier salida que muestre al autor
 * revela entonces el nombre de acceso.
 *
 * Este filtro actúa en cada alta o actualización de cuenta:
 * - si el slug coincide con el nombre de acceso, lo sustituye por un valor
 *   aleatorio sin relación con él;
 * - si el nombre público coincide con el nombre de acceso, lo sustituye por
 *   una etiqueta genérica.
 * Los valores que el usuario haya personalizado no se modifican.
 */
add_filter(
	'wp_pre_insert_user_data',
	function ( $datos, $actualizacion, $id_usuario ) {
		// En las altas, user_login forma parte de $datos; en las actualizaciones,
		// WordPress no lo incluye y se obtiene de la cuenta existente.
		$login = isset( $datos['user_login'] ) ? $datos['user_login'] : '';
		if ( '' === $login && $id_usuario ) {
			$existente = get_userdata( $id_usuario );
			$login     = $existente ? $existente->user_login : '';
		}
		if ( '' === $login ) {
			return $datos;
		}

		if ( isset( $datos['user_nicename'] )
			&& 0 === strcasecmp( $datos['user_nicename'], sanitize_title( $login ) ) ) {
			$datos['user_nicename'] = 'u-' . strtolower( wp_generate_password( 10, false, false ) );
		}

		if ( isset( $datos['display_name'] ) && 0 === strcasecmp( $datos['display_name'], $login ) ) {
			$datos['display_name'] = $id_usuario ? sprintf( 'Usuario %d', $id_usuario ) : 'Usuario';
		}

		return $datos;
	},
	10,
	3
);

/**
 * El apodo (nickname) se inicializa también con el nombre de acceso y se
 * ofrece como nombre público en el perfil. Se alinea con el nombre público.
 */
add_action(
	'profile_update',
	function ( $id_usuario ) {
		$usuario = get_userdata( $id_usuario );
		if ( $usuario && 0 === strcasecmp( (string) $usuario->nickname, $usuario->user_login ) ) {
			update_user_meta( $id_usuario, 'nickname', $usuario->display_name );
		}
	}
);
add_action(
	'user_register',
	function ( $id_usuario ) {
		$usuario = get_userdata( $id_usuario );
		if ( $usuario && 'Usuario' === $usuario->display_name ) {
			// En el alta el ID aún no existía al calcular la etiqueta genérica.
			wp_update_user( array( 'ID' => $id_usuario, 'display_name' => sprintf( 'Usuario %d', $id_usuario ) ) );
		}
		if ( $usuario && 0 === strcasecmp( (string) get_user_meta( $id_usuario, 'nickname', true ), $usuario->user_login ) ) {
			update_user_meta( $id_usuario, 'nickname', get_userdata( $id_usuario )->display_name );
		}
	}
);
