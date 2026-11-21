#!/usr/bin/env bash
# =============================================================================
# Prueba de humo funcional del sitio.
#
# Comprueba que las funciones principales de WordPress siguen operativas tras
# aplicar una mitigación. Se ejecuta después de cada M-0X como control de
# regresión, complementario a la prueba específica de cada hallazgo.
#
# Uso: bash hardening/tests/smoke.sh [URL_BASE] [CONTENEDOR] [USUARIO] [CONTRASEÑA]
# Salida: código 0 si todas las comprobaciones pasan; 1 en caso contrario.
# =============================================================================

BASE="${1:-http://localhost:31338}"
WP="${2:-wpvl-wordpress}"
USER_ADMIN="${3:-admin}"
PASS_ADMIN="${4:-admin}"

JAR="$(mktemp)"
fallos=0
INICIO="$(date -u +%s)"   # Solo se evalúan los errores generados durante esta prueba.

check() {   # check "descripción" "valor obtenido" "valor esperado (regex)"
  if printf '%s' "$2" | grep -qE "$3"; then
    printf "  [OK]    %-55s %s\n" "$1" "$2"
  else
    printf "  [FALLO] %-55s %s (esperado: %s)\n" "$1" "$2" "$3"
    fallos=$((fallos+1))
  fi
}
code() { curl -s -o /dev/null -w '%{http_code}' -b "$JAR" -c "$JAR" "$@"; }

echo "== Sitio público =="
check "Página principal"                 "$(code "$BASE/")"                       '^200$'
check "Entrada del blog (?p=1)"          "$(code "$BASE/?p=1")"                   '^200$'
check "Feed RSS"                         "$(code "$BASE/?feed=rss2")"             '^200$'
check "Página de inicio de sesión"       "$(code "$BASE/wp-login.php")"           '^200$'
check "Recurso estático (jQuery)"        "$(code "$BASE/wp-includes/js/jquery/jquery.js")" '^200$'
css=$(curl -s "$BASE/" | grep -oE "$BASE/wp-content/themes/[^'\"?]+\.css" | head -1)
check "Hoja de estilos del tema activo"  "$(code "${css:-$BASE/wp-content/themes/no-detectado.css}")" '^200$'
check "Índice de la REST API (?rest_route=/)" "$(code "$BASE/?rest_route=/")"    '^200$'
check "REST API: listado de entradas"    "$(code "$BASE/?rest_route=/wp/v2/posts")" '^200$'
check "admin-ajax.php sin acción (400 esperado)" "$(code "$BASE/wp-admin/admin-ajax.php")" '^400$'
check "wp-cron.php"                      "$(code "$BASE/wp-cron.php")"            '^200$'

echo "== Sesión de administrador =="
curl -s -o /dev/null -c "$JAR" "$BASE/wp-login.php"
login=$(curl -s -o /dev/null -b "$JAR" -c "$JAR" -b 'wordpress_test_cookie=WP+Cookie+check' \
  --data-urlencode "log=$USER_ADMIN" --data-urlencode "pwd=$PASS_ADMIN" \
  --data 'wp-submit=Log+In&testcookie=1' -w '%{http_code} %{redirect_url}' "$BASE/wp-login.php")
check "Inicio de sesión (POST wp-login.php)" "$login" '^302 .*/wp-admin/'
check "Escritorio (/wp-admin/) carga"    "$(curl -sL -b "$JAR" "$BASE/wp-admin/" | grep -oE 'id="wpadminbar"|wp-admin-bar' | head -1)" 'wpadminbar|wp-admin-bar'
check "Pantalla de complementos"         "$(code "$BASE/wp-admin/plugins.php")"   '^200$'
check "Editor de entradas"               "$(code "$BASE/wp-admin/post-new.php")"  '^200$'
check "Biblioteca de medios"             "$(code "$BASE/wp-admin/upload.php")"    '^200$'

echo "== Errores del servidor durante la prueba =="
sleep 1
errores=$(docker logs --since "$INICIO" "$WP" 2>&1 | grep -ciE 'PHP (Fatal|Parse) error|\[core:error\]|AH0[0-9]{4}: .*(error|denied)' || true)
check "Errores fatales PHP / Apache durante la prueba" "$errores" '^0$'
if [ "$errores" != "0" ]; then
  docker logs --since "$INICIO" "$WP" 2>&1 | grep -iE 'PHP (Fatal|Parse) error|\[core:error\]' | cut -c1-240 | head -5 | sed 's/^/          /'
fi

rm -f "$JAR"
echo
if [ "$fallos" -eq 0 ]; then echo "RESULTADO: todas las comprobaciones pasaron"; exit 0
else echo "RESULTADO: $fallos comprobación(es) fallaron"; exit 1; fi
