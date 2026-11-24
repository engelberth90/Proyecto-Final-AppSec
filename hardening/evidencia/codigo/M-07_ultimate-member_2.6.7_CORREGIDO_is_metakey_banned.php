<?php
// ============================================================================
// Ultimate Member 2.6.7  (VERSIÓN CORREGIDA — parche de CVE-2023-3460)
// Archivo original del proveedor: includes/core/class-user.php  (línea ~178)
// Descarga: https://downloads.wordpress.org/plugin/ultimate-member.2.6.7.zip
//
// El parche añade una LISTA BLANCA (usermeta_whitelist) para el contexto de
// registro ('submission'): si la clave no está en la lista de claves permitidas,
// se rechaza (denegar por defecto). Esto elimina la evasión de la lista de
// bloqueo: wp_capabilities y cualquier variante quedan fuera, porque no están
// en la lista blanca del formulario.
//
// Además, ahora el registro pasa el contexto:  is_metakey_banned( $meta_key, 'submission' )
// ============================================================================

		public function is_metakey_banned( $meta_key, $context = '' ) {
			$is_banned = false;
			foreach ( $this->banned_keys as $ban ) {
				if ( is_numeric( $meta_key ) || false !== stripos( $meta_key, $ban ) || false !== stripos( remove_accents( $meta_key ), $ban ) ) {
					$is_banned = true;
					break;
				}
			}

			// >>> CONTROL AÑADIDO POR EL PARCHE: lista blanca en el registro <<<
			if ( ! $is_banned && 'submission' === $context && ! in_array( $meta_key, UM()->form()->usermeta_whitelist, true ) ) {
				$is_banned = true;
			}

			return $is_banned;
		}

		// Invocación en el procesamiento del registro (class-user.php:210):
		//     if ( $this->is_metakey_banned( $meta_key, 'submission' ) ) { ... }
