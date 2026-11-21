#!/usr/bin/env bash
# =============================================================================
# M-05 - Verificación del XSS reflejado en Ninja Forms (hallazgo 2.5,
#        CVE-2023-37979).
#
# Comprueba tres aspectos:
#   1. Versión instalada fuera del rango vulnerable (corregido en 3.6.26).
#   2. Presencia en el código del saneador que introduce el parche del proveedor.
#   3. Que el vector del informe (acción nf_batch_process) no refleje el payload
#      sin escapar.
#
# Uso: bash hardening/tests/m05-xss-ninja-forms.sh [URL_BASE] [CONTENEDOR]
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/lib-credenciales.sh"
BASE="${1:-http://localhost:31338}"
WP="${2:-wpvl-wordpress}"
PLUG=/var/www/html/wp-content/plugins/ninja-forms
VULN_MAX="3.6.25"   # Última versión vulnerable; el parche es 3.6.26.

wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }
ok() { printf "  [OK]    %s\n" "$1"; }
no() { printf "  [FALLO] %s\n" "$1"; }

VER=$(docker exec "$WP" sed -n 's/^Stable tag: *//p' "$PLUG/readme.txt" 2>/dev/null | tr -d '\r')
EST=$(wpc plugin get ninja-forms --field=status 2>/dev/null | tr -d '\r')
echo "Ninja Forms: versión ${VER:-(ausente)} · estado ${EST:-(ausente)}"

echo
echo "== 1. Versión fuera del rango vulnerable =="
if [ -z "$VER" ]; then
  ok "El complemento no está presente (superficie de ataque eliminada)"
elif [ "$(printf '%s\n%s\n' "$VER" "$VULN_MAX" | sort -V | tail -1)" != "$VULN_MAX" ] && [ "$VER" != "$VULN_MAX" ]; then
  ok "Versión $VER posterior a $VULN_MAX (fuera del rango de CVE-2023-37979)"
else
  no "Versión $VER dentro del rango vulnerable (<= $VULN_MAX)"
fi

echo
echo "== 2. Parche del proveedor presente en el código =="
if [ -n "$VER" ]; then
  if docker exec "$WP" test -f "$PLUG/includes/Handlers/Sanitizer.php"; then
    ok "Clase Sanitizer presente (saneador introducido en 3.6.26)"
  else
    no "Clase Sanitizer ausente (código vulnerable)"
  fi
else
  ok "Sin archivos del complemento que revisar"
fi

echo
echo "== 3. Vector del informe (nf_batch_process) =="
JAR=$(mktemp); curl -s -o /dev/null -c "$JAR" "$BASE/wp-login.php"
curl -s -o /dev/null -b "$JAR" -c "$JAR" -b 'wordpress_test_cookie=WP+Cookie+check' \
  --data-urlencode "log=$ADMIN_USER" --data-urlencode "pwd=$ADMIN_PASS" \
  --data 'wp-submit=Log+In&testcookie=1' "$BASE/wp-login.php"
RESP=$(curl -s -b "$JAR" -X POST "$BASE/wp-admin/admin-ajax.php" \
  --data-urlencode "action=nf_batch_process" \
  --data-urlencode "batch_type=import_form_template" \
  --data-urlencode "extraData[template]=formtemplate-contactformd" \
  --data-urlencode "method_override=_respond" \
  --data-urlencode 'data=XSSPROBE<img src=x onerror=alert(document.domain)>')
rm -f "$JAR"
printf "  Respuesta (120): %s\n" "$(printf '%s' "$RESP" | head -c 120)"
if printf '%s' "$RESP" | grep -qF '<img src=x onerror=alert(document.domain)>'; then
  no "El payload se refleja SIN escapar (XSS explotable)"
else
  ok "El payload no se refleja sin escapar"
fi
