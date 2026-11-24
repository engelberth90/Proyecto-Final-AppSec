<?php
// ============================================================================
// WP Fastest Cache 1.2.2  (VERSIÓN CORREGIDA — parche de CVE-2023-6063)
// Archivo original del proveedor: inc/cache.php  (líneas ~475-500)
// Descarga: https://downloads.wordpress.org/plugin/wp-fastest-cache.1.2.2.zip
//
// El parche añade UNA línea: $username = esc_sql($username);
// esc_sql() escapa los caracteres especiales de SQL (entre ellos la comilla
// doble) del valor tomado de la cookie, de modo que el payload deja de romper
// la cadena user_login = "$username" y SLEEP() nunca se ejecuta.
// ============================================================================

		public function is_user_admin(){
			global $wpdb;

			foreach ((array)$_COOKIE as $cookie_key => $cookie_value){
				if(preg_match("/wordpress_logged_in/i", $cookie_key)){
					$username = preg_replace("/^([^\|]+)\|.+/", "$1", $cookie_value);
					break;
				}
			}

			if(isset($username) && $username){
				$username = esc_sql($username);   // <<< LÍNEA AÑADIDA POR EL PARCHE

				$res = $wpdb->get_var("SELECT `$wpdb->users`.`ID`, `$wpdb->users`.`user_login`, `$wpdb->usermeta`.`meta_key`, `$wpdb->usermeta`.`meta_value`
									   FROM `$wpdb->users`
									   INNER JOIN `$wpdb->usermeta`
									   ON `$wpdb->users`.`user_login` = \"$username\" AND
									   `$wpdb->usermeta`.`meta_key` LIKE \"%_user_level\" AND
									   `$wpdb->usermeta`.`meta_value` = \"10\" AND
									   `$wpdb->users`.`ID` = `$wpdb->usermeta`.user_id ;"
									);

				return $res;
			}

			return false;
		}
