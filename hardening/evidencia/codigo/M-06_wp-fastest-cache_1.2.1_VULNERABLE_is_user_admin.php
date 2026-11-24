<?php
// ============================================================================
// WP Fastest Cache 1.2.1  (VERSIÓN VULNERABLE — CVE-2023-6063)
// Archivo original del proveedor: inc/cache.php  (líneas ~475-498)
// Descarga: https://downloads.wordpress.org/plugin/wp-fastest-cache.1.2.1.zip
//
// El nombre de usuario se toma de la cookie wordpress_logged_in y se concatena
// SIN SANEAR dentro de la consulta SQL (user_login = "$username"), lo que
// permite una inyección SQL ciega basada en tiempo sin autenticación.
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
				// >>> FALTA EL SANEADO DEL VALOR TOMADO DE LA COOKIE <<<
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
