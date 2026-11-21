#!/usr/bin/env bash
# =============================================================================
# M-03 - Verificación de enumeración de usuarios (hallazgo 2.1).
#
# Reproduce la prueba de concepto del informe (REST API sin autenticación) y la
# amplía a otras vías por las que WordPress revela nombres de usuario:
# archivos de autor (?author=N), oEmbed y el feed RSS.
#
# Criterio: una respuesta FILTRA si contiene el nombre de acceso (user_login)
# de alguna cuenta. Los nombres de acceso se obtienen del propio sitio, de modo
# que la prueba no depende de conocerlos de antemano.
#
# Uso: bash hardening/tests/m03-enumeracion-usuarios.sh [URL_BASE] [CONTENEDOR]
# Variables opcionales: SUB_USER/SUB_PASS, EDITOR_USER/EDITOR_PASS, ADMIN_USER/ADMIN_PASS
# =============================================================================

BASE="${1:-http://localhost:31338}"
WP="${2:-wpvl-wordpress}"
SUB_USER="${SUB_USER:-subscriber}";   SUB_PASS="${SUB_PASS:-password123}"
EDITOR_USER="${EDITOR_USER:-editor}"; EDITOR_PASS="${EDITOR_PASS:-editor}"
ADMIN_USER="${ADMIN_USER:-admin}";    ADMIN_PASS="${ADMIN_PASS:-admin}"

LOGINS=$(docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp \
  --allow-root --path=/var/www/html user list --field=user_login 2>/dev/null)
PATRON=$(printf '%s\n' $LOGINS | sed 's/[][\.*^$/]/\\&/g' | paste -sd'|')

filtrados=0
evaluar() {   # evaluar "descripción" "cuerpo+cabeceras de la respuesta" "código HTTP"
  local hallado
  hallado=$(printf '%s' "$2" | grep -oiwE "\"slug\":\"($PATRON)\"|author_name\":\"($PATRON)\"|/author/($PATRON)/|<dc:creator><!\[CDATA\[($PATRON)\]\]>|author-($PATRON)( |\")|Location: .*author/($PATRON)|<title>($PATRON) &#8211;|Posts by ($PATRON) Feed" | head -1)
  if [ -n "$hallado" ]; then
    printf "  %-58s HTTP %-4s FILTRA   %s\n" "$1" "$3" "$hallado"
    filtrados=$((filtrados+1))
  else
    printf "  %-58s HTTP %-4s sin fuga\n" "$1" "$3"
  fi
}
solicitar() {  # solicitar URL [opciones curl...] -> imprime cabeceras+cuerpo; código en $HTTP
  local tmp; tmp=$(mktemp)
  HTTP=$(curl -s -D "$tmp.h" -o "$tmp" -w '%{http_code}' "$@")
  RESP="$(cat "$tmp.h" "$tmp")"; rm -f "$tmp" "$tmp.h"
}
iniciar_sesion() {  # iniciar_sesion USUARIO CLAVE JAR -> NONCE de la REST API
  curl -s -o /dev/null -c "$3" "$BASE/wp-login.php"
  curl -s -o /dev/null -b "$3" -c "$3" -b 'wordpress_test_cookie=WP+Cookie+check' \
    --data-urlencode "log=$1" --data-urlencode "pwd=$2" --data 'wp-submit=Log+In&testcookie=1' \
    "$BASE/wp-login.php"
  NONCE=$(curl -s -b "$3" "$BASE/wp-admin/admin-ajax.php?action=rest-nonce")
}

echo "Cuentas del sitio: $(printf '%s ' $LOGINS)"
echo
echo "== 1. Visitante sin autenticación =="
solicitar "$BASE/?rest_route=/wp/v2/users";               evaluar "REST ?rest_route=/wp/v2/users (PoC del informe)" "$RESP" "$HTTP"
solicitar "$BASE/wp-json/wp/v2/users";                    evaluar "REST /wp-json/wp/v2/users" "$RESP" "$HTTP"
solicitar "$BASE/?rest_route=/wp/v2/users/1";             evaluar "REST /wp/v2/users/1" "$RESP" "$HTTP"
solicitar "$BASE/?rest_route=/wp/v2/users&search=a";      evaluar "REST /wp/v2/users?search=a" "$RESP" "$HTTP"
solicitar "$BASE/?rest_route=/wp/v2/users&per_page=100&context=embed"; evaluar "REST /wp/v2/users?context=embed" "$RESP" "$HTTP"
for id in 1 2 3; do
  solicitar "$BASE/?author=$id";                          evaluar "Archivo de autor ?author=$id" "$RESP" "$HTTP"
done
solicitar "$BASE/?rest_route=/oembed/1.0/embed&url=$BASE/?p=1"; evaluar "oEmbed de la entrada 1" "$RESP" "$HTTP"
solicitar "$BASE/?feed=rss2";                             evaluar "Feed RSS (dc:creator)" "$RESP" "$HTTP"
solicitar "$BASE/?p=1";                                   evaluar "Entrada 1 (clases y enlaces de autor)" "$RESP" "$HTTP"

echo
echo "== 2. Suscriptor autenticado (no debe enumerar cuentas) =="
JAR=$(mktemp); iniciar_sesion "$SUB_USER" "$SUB_PASS" "$JAR"
solicitar "$BASE/?rest_route=/wp/v2/users" -b "$JAR" -H "X-WP-Nonce: $NONCE"
evaluar "REST /wp/v2/users como suscriptor" "$RESP" "$HTTP"
rm -f "$JAR"

anonimos_y_suscriptor=$filtrados

echo
echo "== 3. Controles funcionales (deben conservar el acceso) =="
JAR=$(mktemp); iniciar_sesion "$EDITOR_USER" "$EDITOR_PASS" "$JAR"
c=$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" -H "X-WP-Nonce: $NONCE" "$BASE/?rest_route=/wp/v2/users&who=authors")
printf "  %-58s HTTP %s\n" "Editor: autores para el editor de bloques (who=authors)" "$c"
rm -f "$JAR"
JAR=$(mktemp); iniciar_sesion "$ADMIN_USER" "$ADMIN_PASS" "$JAR"
c=$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" -H "X-WP-Nonce: $NONCE" "$BASE/?rest_route=/wp/v2/users")
printf "  %-58s HTTP %s\n" "Administrador: listado de usuarios por REST" "$c"
c=$(curl -s -o /dev/null -w '%{http_code}' -b "$JAR" "$BASE/wp-admin/users.php")
printf "  %-58s HTTP %s\n" "Administrador: pantalla de usuarios (/wp-admin/users.php)" "$c"
rm -f "$JAR"

echo
echo "Respuestas con fuga (visitante y suscriptor): $anonimos_y_suscriptor"
