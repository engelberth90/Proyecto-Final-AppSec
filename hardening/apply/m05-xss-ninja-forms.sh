#!/usr/bin/env bash
# =============================================================================
# M-05 - Aplicación de la mitigación del XSS reflejado en Ninja Forms
#        (hallazgo 2.5, CVE-2023-37979).
#
# La mitigación es la actualización del complemento a la versión 3.6.26, que
# incorpora el saneador del proveedor (clase Sanitizer). Se reemplazan los
# archivos del complemento y se mantiene su estado natural en el laboratorio:
# inactivo.
#
# Nota sobre el entorno: Ninja Forms (tanto la versión vulnerable como la
# parcheada) declara "Requires at least: 6.0" y el laboratorio ejecuta
# WordPress 5.3.2. Por tanto el complemento no puede activarse de forma normal
# en este entorno; la versión parcheada, además, provoca un error fatal si se
# fuerza su activación. Con el complemento inactivo, su endpoint AJAX no se
# registra y el vector no es alcanzable; los archivos quedan actualizados, con
# el código vulnerable sustituido. El uso funcional del complemento requeriría
# actualizar el núcleo de WordPress (M-08).
#
# Uso: bash hardening/apply/m05-xss-ninja-forms.sh [DIRECTORIO_DEL_LAB]
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
WP="wpvl-wordpress"
wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }

echo "[1/3] Actualización de Ninja Forms a 3.6.26 (versión parcheada)"
wpc plugin install ninja-forms --version=3.6.26 --force

echo "[2/3] Verificación del estado (debe permanecer inactivo en este entorno)"
# Si una ejecución previa lo dejó forzado-activo, se retira de active_plugins.
cat > /tmp/m05-deact.php <<'PHP'
<?php
$a = array_values( array_diff( get_option('active_plugins'), array('ninja-forms/ninja-forms.php') ) );
update_option('active_plugins', $a);
echo "ninja-forms inactivo\n";
PHP
docker cp /tmp/m05-deact.php "$WP:/tmp/m05-deact.php"
wpc eval-file /tmp/m05-deact.php

echo "[3/3] Comprobación del saneador y del sitio"
docker exec "$WP" test -f /var/www/html/wp-content/plugins/ninja-forms/includes/Handlers/Sanitizer.php \
  && echo "  Sanitizer.php presente" || echo "  AVISO: Sanitizer.php ausente"
echo "  home -> HTTP $(curl -s -o /dev/null -w '%{http_code}' http://localhost:31338/)"
