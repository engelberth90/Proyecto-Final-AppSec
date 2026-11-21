<?php
/**
 * Plugin Name: M-08 Ocultar versión de WordPress
 * Description: Retira el número de versión de WordPress de la salida pública
 *              (etiqueta generator, feeds y parámetros de versión en recursos).
 * Version:     1.0.0
 *
 * Complementa la actualización de componentes (hallazgo 2.4). No sustituye a la
 * actualización: reduce la información que un escáner usa para identificar
 * versiones, pero la mitigación real es ejecutar versiones con soporte.
 */

defined( 'ABSPATH' ) || exit;

// Etiqueta <meta name="generator"> en HTML y en los feeds.
remove_action( 'wp_head', 'wp_generator' );
add_filter( 'the_generator', '__return_empty_string' );

// Parámetro ?ver=<versión de WP> en los recursos del núcleo (CSS y JS).
add_filter( 'style_loader_src', 'm08_quitar_ver_nucleo', 9999 );
add_filter( 'script_loader_src', 'm08_quitar_ver_nucleo', 9999 );
function m08_quitar_ver_nucleo( $src ) {
	global $wp_version;
	if ( $src && false !== strpos( $src, 'ver=' . $wp_version ) ) {
		$src = remove_query_arg( 'ver', $src );
	}
	return $src;
}
