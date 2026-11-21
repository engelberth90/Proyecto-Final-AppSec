#!/usr/bin/env bash
# =============================================================================
# M-03 - Aplicación de la mitigación de enumeración de usuarios
#        (hallazgo 2.1 del informe de pentesting).
#
# Uso:        bash hardening/apply/m03-enumeracion-usuarios.sh [DIRECTORIO_DEL_LAB]
# Requisitos: M-01 y M-02 aplicadas y el laboratorio en ejecución.
#
# El script es idempotente.
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
WP="wpvl-wordpress"
MU_ORIGEN="$LAB/hardening/src/mu-plugins/m03-enumeracion-usuarios.php"
MU_DESTINO="/var/www/html/wp-content/mu-plugins/m03-enumeracion-usuarios.php"
wpcli() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --path=/var/www/html --allow-root "$@"; }

echo "[1/3] Instalación del mu-plugin en el volumen del sitio"
docker exec "$WP" install -d -o www-data -g www-data -m 0755 /var/www/html/wp-content/mu-plugins
docker cp "$MU_ORIGEN" "$WP:$MU_DESTINO"
docker exec "$WP" chown www-data:www-data "$MU_DESTINO"
docker exec "$WP" php -l "$MU_DESTINO"
wpcli plugin list --status=must-use --fields=name,status

echo "[2/3] Corrección de cuentas existentes (slug y nombre público iguales al nombre de acceso)"
# wp_update_user() recalcula los datos de cada cuenta y aplica el filtro
# wp_pre_insert_user_data del mu-plugin, que sustituye los valores derivados
# del nombre de acceso.
wpcli eval '
foreach ( get_users( array( "fields" => array( "ID" ) ) ) as $u ) {
	wp_update_user( array( "ID" => $u->ID ) );
}'
wpcli user list --fields=ID,user_login,user_nicename,display_name

echo "[3/3] Limpieza de caché de páginas (los feeds y archivos de autor pueden estar en caché)"
wpcli cache flush >/dev/null || true
wpcli litespeed-purge all >/dev/null 2>&1 || true
docker exec "$WP" sh -c 'rm -rf /var/www/html/wp-content/cache/all/* 2>/dev/null || true'
echo "Listo"
