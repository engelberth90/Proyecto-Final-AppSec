#!/usr/bin/env bash
# =============================================================================
# M-06 - Aplicación de la mitigación de la inyección SQL ciega en WP Fastest
#        Cache (hallazgo 2.6, CVE-2023-6063).
#
# La mitigación es la actualización del complemento a la versión 1.2.2, que
# sanea con esc_sql() el valor tomado de la cookie antes de usarlo en la
# consulta. La versión 1.2.2 es compatible con WordPress 5.3, de modo que el
# complemento permanece activo y funcional.
#
# Uso: bash hardening/apply/m06-sqli-wp-fastest-cache.sh [DIRECTORIO_DEL_LAB]
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
WP="wpvl-wordpress"
wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }

echo "[1/2] Actualización de WP Fastest Cache a 1.2.2 (versión parcheada)"
wpc plugin install wp-fastest-cache --version=1.2.2 --force
wpc plugin activate wp-fastest-cache >/dev/null 2>&1 || true

echo "[2/2] Comprobación del saneado y del sitio"
if docker exec "$WP" sed -n '474,492p' /var/www/html/wp-content/plugins/wp-fastest-cache/inc/cache.php | grep -q 'esc_sql'; then
  echo "  esc_sql() presente en is_user_admin()"
else
  echo "  AVISO: esc_sql() no encontrado"
fi
echo "  home -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:31338/)"
