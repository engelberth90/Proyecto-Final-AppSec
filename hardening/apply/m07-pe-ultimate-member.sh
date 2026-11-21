#!/usr/bin/env bash
# =============================================================================
# M-07 - Aplicación de la mitigación de la escalada de privilegios en Ultimate
#        Member (hallazgo 2.7, CVE-2023-3460).
#
# La mitigación es la actualización del complemento a la versión 2.6.7, que
# sustituye la lista de bloqueo de claves de metadatos (evadible) por una lista
# blanca (is_metakey_banned / usermeta_whitelist).
#
# Ultimate Member 2.6.7 declara "Requires at least: 5.5" y el laboratorio
# ejecuta WordPress 5.3.2, por lo que el complemento no puede activarse de forma
# normal. Se actualizan sus archivos (código vulnerable sustituido, huella de
# versión corregida) y se mantiene inactivo, su estado natural en el laboratorio,
# con lo que el vector de registro no es alcanzable. El uso funcional del
# complemento requeriría actualizar el núcleo de WordPress (M-08).
#
# Uso: bash hardening/apply/m07-pe-ultimate-member.sh [DIRECTORIO_DEL_LAB]
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
WP="wpvl-wordpress"
wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }

echo "[1/3] Actualización de Ultimate Member a 2.6.7 (versión parcheada)"
wpc plugin install ultimate-member --version=2.6.7 --force

echo "[2/3] Verificación del estado (debe permanecer inactivo en este entorno)"
cat > /tmp/m07-deact.php <<'PHP'
<?php
$a = array_values( array_diff( get_option('active_plugins'), array('ultimate-member/ultimate-member.php') ) );
update_option('active_plugins', $a);
echo "ultimate-member inactivo\n";
PHP
docker cp /tmp/m07-deact.php "$WP:/tmp/m07-deact.php"
wpc eval-file /tmp/m07-deact.php

echo "[3/3] Comprobación del control de lista blanca y del sitio"
if docker exec "$WP" grep -q 'function is_metakey_banned' /var/www/html/wp-content/plugins/ultimate-member/includes/core/class-user.php; then
  echo "  is_metakey_banned() presente"
else
  echo "  AVISO: is_metakey_banned() ausente"
fi
echo "  home -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:31338/)"
