#!/usr/bin/env bash
# =============================================================================
# M-08 - Verificación de componentes desactualizados (hallazgo 2.4).
#
# Comprueba que la plataforma ejecuta versiones con soporte y que no revela
# sus versiones:
#   1. Núcleo de WordPress en una rama soportada (no 5.3.2).
#   2. PHP 8.x y Apache sin versión en la cabecera Server.
#   3. Ningún complemento ni tema con actualización pendiente.
#   4. Los complementos con CVE del informe, en versión posterior a la vulnerable.
#   5. La versión de WordPress y la de PHP no se divulgan.
#
# Uso: bash hardening/tests/m08-componentes-desactualizados.sh [URL_BASE] [CONTENEDOR]
# =============================================================================

BASE="${1:-http://localhost:31338}"
WP="${2:-wpvl-wordpress}"
wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }
ok() { printf "  [OK]    %s\n" "$1"; }
no() { printf "  [FALLO] %s\n" "$1"; }

CORE=$(wpc core version 2>/dev/null | tr -d '\r')
PHPV=$(docker exec "$WP" php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)
echo "Núcleo WordPress: $CORE · PHP: $PHPV"

echo
echo "== 1. Núcleo en rama soportada =="
case "$CORE" in
  5.3.*|5.2.*|""|4.*) no "WordPress $CORE sin soporte" ;;
  *) ok "WordPress $CORE (rama con soporte)" ;;
esac

echo
echo "== 2. PHP 8.x y Apache sin versión divulgada =="
case "$PHPV" in 8.*|9.*) ok "PHP $PHPV (con soporte)";; *) no "PHP $PHPV sin soporte";; esac
SRV=$(curl -sI "$BASE/" | sed -n 's/\r//; s/^[Ss]erver: *//p')
if printf '%s' "$SRV" | grep -qE '[0-9]+\.[0-9]+'; then no "Cabecera Server revela versión: $SRV"; else ok "Cabecera Server sin versión: ${SRV:-(ausente)}"; fi

echo
echo "== 3. Sin actualizaciones pendientes =="
NPLUG=$(wpc plugin list --update=available --field=name 2>/dev/null | grep -c . || true)
NTHEME=$(wpc theme list --update=available --field=name 2>/dev/null | grep -c . || true)
[ "$NPLUG" = 0 ] && ok "Todos los complementos al día" || no "$NPLUG complemento(s) con actualización pendiente"
[ "$NTHEME" = 0 ] && ok "Todos los temas al día" || no "$NTHEME tema(s) con actualización pendiente"

echo
echo "== 4. Complementos con CVE del informe, fuera del rango vulnerable =="
verifica_plugin() {   # slug  version_vulnerable_max
  local slug="$1" vmax="$2" ver
  ver=$(wpc plugin get "$slug" --field=version 2>/dev/null | tr -d '\r')
  if [ -z "$ver" ]; then
    ok "$slug eliminado (superficie de ataque retirada)"
  elif [ "$ver" != "$vmax" ] && [ "$(printf '%s\n%s\n' "$ver" "$vmax" | sort -V | tail -1)" != "$vmax" ]; then
    ok "$slug $ver (> $vmax)"
  else
    no "$slug $ver (<= $vmax)"
  fi
}
verifica_plugin wp-statistics          13.2.10
verifica_plugin ultimate-member        2.6.6
verifica_plugin royal-elementor-addons 1.3.78
verifica_plugin popup-builder          4.2.3
verifica_plugin woocommerce            7.0.0
verifica_plugin ninja-forms            3.6.25
verifica_plugin wp-fastest-cache       1.2.1

echo
echo "== 5. La versión de WordPress no se divulga (meta generator) =="
GEN=$(curl -s "$BASE/?cb=$RANDOM" | grep -io '<meta name="generator" content="WordPress[^"]*"' | head -1)
if [ -n "$GEN" ]; then no "Se divulga la versión de WordPress: $GEN"; else ok "Sin meta generator de WordPress"; fi
XPB=$(curl -sI "$BASE/" | grep -i '^x-powered-by:')
if [ -n "$XPB" ]; then no "Cabecera X-Powered-By presente: $XPB"; else ok "Sin cabecera X-Powered-By"; fi
