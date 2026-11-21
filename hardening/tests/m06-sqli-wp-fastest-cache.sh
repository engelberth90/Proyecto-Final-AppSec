#!/usr/bin/env bash
# =============================================================================
# M-06 - Verificación de la inyección SQL ciega en WP Fastest Cache
#        (hallazgo 2.6, CVE-2023-6063).
#
# La función is_user_admin() toma el nombre de usuario de la cookie
# wordpress_logged_in y lo inserta sin sanear en una consulta SQL. Un visitante
# sin autenticación puede inferir datos por el tiempo de respuesta.
#
# La función solo se ejecuta si la caché del complemento está habilitada, como
# en cualquier sitio real que lo utilice. La prueba la habilita (idempotente)
# para que el vector sea alcanzable, y mide:
#   1. Versión fuera del rango vulnerable (corregido en 1.2.2).
#   2. Presencia del saneado esc_sql() en el código.
#   3. Retardo inducido por un payload SLEEP(2) enviado en la cookie.
#
# Uso: bash hardening/tests/m06-sqli-wp-fastest-cache.sh [URL_BASE] [CONTENEDOR]
# =============================================================================

BASE="${1:-http://localhost:31338}"
WP="${2:-wpvl-wordpress}"
PLUG=/var/www/html/wp-content/plugins/wp-fastest-cache
VULN_MAX="1.2.1"
UMBRAL=1.5   # segundos de retardo que delatan la inyección

wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }
ok() { printf "  [OK]    %s\n" "$1"; }
no() { printf "  [FALLO] %s\n" "$1"; }

# Habilita la caché del complemento (representa un despliegue real que lo usa).
wpc option update WpFastestCache '{"wpFastestCacheStatus":"on"}' >/dev/null 2>&1

VER=$(docker exec "$WP" sed -n 's/^Stable tag: *//p' "$PLUG/readme.txt" 2>/dev/null | tr -d '\r')
EST=$(wpc plugin get wp-fastest-cache --field=status 2>/dev/null | tr -d '\r')
echo "WP Fastest Cache: versión ${VER:-(ausente)} · estado ${EST:-(ausente)}"

echo
echo "== 1. Versión fuera del rango vulnerable =="
if [ -n "$VER" ] && [ "$VER" != "$VULN_MAX" ] && [ "$(printf '%s\n%s\n' "$VER" "$VULN_MAX" | sort -V | tail -1)" != "$VULN_MAX" ]; then
  ok "Versión $VER posterior a $VULN_MAX (fuera del rango de CVE-2023-6063)"
else
  no "Versión ${VER:-?} dentro del rango vulnerable (<= $VULN_MAX)"
fi

echo
echo "== 2. Saneado esc_sql() presente en is_user_admin() =="
# Se extrae el cuerpo de la función (su posición varía entre versiones) y se
# comprueba que el valor de la cookie se sanea antes de la consulta.
if docker exec "$WP" awk '/function is_user_admin/{f=1} f{print} f&&/return false/{exit}' "$PLUG/inc/cache.php" 2>/dev/null | grep -qE 'esc_sql|\$wpdb->prepare'; then
  ok "La consulta sanea el valor de la cookie con esc_sql()"
else
  no "La consulta usa el valor de la cookie sin esc_sql()"
fi

echo
echo "== 3. Inyección SQL ciega basada en tiempo (cookie, sin autenticación) =="
INJ='wordpress_logged_in_t=x%22%20OR%20(SELECT%201%20FROM%20(SELECT%20SLEEP(2))z)%20OR%20%22'
BEN='wordpress_logged_in_t=benigno'
t() { curl -s -o /dev/null -w '%{time_total}' -H "Cookie: $1" "$BASE/"; }
TB=$(t "$BEN"); TI=$(t "$INJ")
printf "  tiempo benigno   : %ss\n" "$TB"
printf "  tiempo inyectado : %ss\n" "$TI"
DELTA=$(awk "BEGIN{print $TI-$TB}")
printf "  diferencia       : %ss\n" "$DELTA"
if awk "BEGIN{exit !($TI > $UMBRAL && $DELTA > 1.0)}"; then
  no "El payload SLEEP(2) induce un retardo (SQLi explotable)"
else
  ok "El payload no induce retardo (SQLi no explotable)"
fi
