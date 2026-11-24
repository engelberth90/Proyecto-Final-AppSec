<?php
// ============================================================================
// Ultimate Member 2.6.6  (VERSIÓN VULNERABLE — CVE-2023-3460)
// Archivo original del proveedor: includes/core/class-user.php  (línea ~178)
// Descarga: https://downloads.wordpress.org/plugin/ultimate-member.2.6.6.zip
//
// El control de claves de metadatos es una LISTA DE BLOQUEO: solo rechaza las
// claves que contienen una subcadena "prohibida". Es evadible — una clave
// manipulada que no coincida con la lista (p.ej. con mayúsculas/acentos/barras)
// pasa el control y llega a la base de datos. Así, durante el registro, un
// visitante puede fijar wp_capabilities y convertirse en administrador.
//
// Además, en el registro se invoca SIN contexto:  is_metakey_banned( $meta_key )
// ============================================================================

		public function is_metakey_banned( $meta_key ) {
			$is_banned = false;
			foreach ( $this->banned_keys as $ban ) {
				if ( is_numeric( $meta_key ) || false !== stripos( $meta_key, $ban ) ) {
					$is_banned = true;
					break;
				}
			}

			return $is_banned;
		}

		// Invocación en el procesamiento del registro (class-user.php:206):
		//     if ( $this->is_metakey_banned( $meta_key ) ) { ... }
