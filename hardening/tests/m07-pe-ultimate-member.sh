#!/usr/bin/env bash
# =============================================================================
# M-07 - Verificación de la escalada de privilegios en Ultimate Member
#        (hallazgo 2.7, CVE-2023-3460).
#
# Ultimate Member 2.6.6 permite, durante el registro, fijar claves de metadatos
# arbitrarias (incluida wp_capabilities) evadiendo una lista de bloqueo, lo que
# convierte a un visitante en administrador. El parche (2.6.7) sustituye esa
# lista de bloqueo por una lista blanca de claves permitidas.
#
# Ultimate Member (2.6.6 y 2.6.7) declara "Requires at least: 5.5"; el
# laboratorio ejecuta WordPress 5.3.2, por lo que el complemento no se activa
# por medios normales. La verificación se basa, como en el informe, en la
# versión instalada y, además, en la presencia del control de la versión
# parcheada. La verificación funcional completa requiere el núcleo actualizado
# (M-08).
#
# Uso: bash hardening/tests/m07-pe-ultimate-member.sh [URL_BASE] [CONTENEDOR]
# =============================================================================

WP="${2:-wpvl-wordpress}"
PLUG=/var/www/html/wp-content/plugins/ultimate-member
VULN_MAX="2.6.6"

wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }
ok() { printf "  [OK]    %s\n" "$1"; }
no() { printf "  [FALLO] %s\n" "$1"; }

VER=$(docker exec "$WP" sed -n 's/^Stable tag: *//p' "$PLUG/readme.txt" 2>/dev/null | tr -d '\r')
EST=$(wpc plugin get ultimate-member --field=status 2>/dev/null | tr -d '\r')
echo "Ultimate Member: versión ${VER:-(ausente)} · estado ${EST:-(ausente)}"

echo
echo "== 1. Versión fuera del rango vulnerable =="
if [ -n "$VER" ] && [ "$VER" != "$VULN_MAX" ] && [ "$(printf '%s\n%s\n' "$VER" "$VULN_MAX" | sort -V | tail -1)" != "$VULN_MAX" ]; then
  ok "Versión $VER posterior a $VULN_MAX (fuera del rango de CVE-2023-3460)"
else
  no "Versión ${VER:-?} dentro del rango vulnerable (<= $VULN_MAX)"
fi

echo
echo "== 2. Control de la versión parcheada: lista blanca de claves de metadatos =="
if docker exec "$WP" grep -q 'function is_metakey_banned' "$PLUG/includes/core/class-user.php" 2>/dev/null \
   && docker exec "$WP" grep -rq 'usermeta_whitelist' "$PLUG/includes/core/" 2>/dev/null; then
  ok "Presente is_metakey_banned() con lista blanca usermeta_whitelist"
else
  no "Ausente el control de lista blanca (lógica de lista de bloqueo evadible)"
fi

echo
echo "== 3. Estado en el laboratorio =="
if [ "$EST" = "active" ]; then
  echo "  Nota: el complemento está activo; su uso funcional requiere WordPress >= 5.5."
else
  ok "Complemento inactivo: el vector de registro no es alcanzable en este entorno"
fi
