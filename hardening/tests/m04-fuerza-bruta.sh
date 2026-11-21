#!/usr/bin/env bash
# =============================================================================
# M-04 - Verificación de fuerza bruta mediante XML-RPC (hallazgo 2.2).
#
# Reproduce el vector del informe (wp.getUsersBlogs vía /xmlrpc.php) y comprueba
# las demás medidas: cabeceras que anuncian el endpoint, uniformidad de los
# mensajes de error y límite de intentos en el inicio de sesión.
#
# Uso: bash hardening/tests/m04-fuerza-bruta.sh [URL_BASE] [CONTENEDOR]
# Credenciales: véase lib-credenciales.sh.
# =============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/lib-credenciales.sh"
BASE="${1:-http://localhost:31338}"
WP="${2:-wpvl-wordpress}"

ok() { printf "  [OK]    %s\n" "$1"; }
no() { printf "  [FALLO] %s\n" "$1"; }

echo "== 1. XML-RPC (vector del informe) =="
XML='<?xml version="1.0"?><methodCall><methodName>wp.getUsersBlogs</methodName><params><param><value>'"$ADMIN_USER"'</value></param><param><value>'"$ADMIN_PASS"'</value></param></params></methodCall>'
RESP_XML="$(curl -s -w '\n%{http_code}' -d "$XML" "$BASE/xmlrpc.php")"
CODE_XML="$(printf '%s' "$RESP_XML" | tail -1)"
CUERPO_XML="$(printf '%s' "$RESP_XML" | sed '$d')"
printf "  xmlrpc.php -> HTTP %s\n" "$CODE_XML"
if [ "$CODE_XML" = "200" ] && printf '%s' "$CUERPO_XML" | grep -qiE 'isAdmin|<name>|methodResponse'; then
  no "xmlrpc.php procesa peticiones de autenticación (fuerza bruta posible)"
else
  ok "xmlrpc.php no procesa peticiones de autenticación"
fi

CODE_MULTI="$(curl -s -o /dev/null -w '%{http_code}' -d '<?xml version="1.0"?><methodCall><methodName>system.multicall</methodName></methodCall>' "$BASE/xmlrpc.php")"
printf "  system.multicall -> HTTP %s %s\n" "$CODE_MULTI" "$( [ "$CODE_MULTI" = 200 ] && echo '(amplificación disponible)' || echo '(bloqueado)')"

echo
echo "== 2. Divulgación del endpoint =="
if curl -sI "$BASE/?p=1" | grep -qi '^X-Pingback:'; then no "Cabecera X-Pingback presente"; else ok "Cabecera X-Pingback ausente"; fi
if curl -s "$BASE/?p=1" | grep -qi 'rel="EditURI"'; then no "Enlace RSD presente"; else ok "Enlace RSD ausente"; fi

echo
echo "== 3. Mensajes de error del inicio de sesión =="
intento() {   # intento USUARIO CLAVE -> imprime el mensaje de error normalizado
  curl -s -b 'wordpress_test_cookie=WP+Cookie+check' \
    --data-urlencode "log=$1" --data-urlencode "pwd=$2" --data 'wp-submit=Log+In&testcookie=1' \
    "$BASE/wp-login.php" \
    | tr '\n' ' ' \
    | sed -n 's/.*<div id="login_error">//p' | sed 's|</div>.*||' \
    | sed 's/<[^>]*>//g' | tr -s ' ' | sed 's/^ *//; s/ *$//'
}
MSG_USUARIO="$(intento 'usuario_que_no_existe_x9' 'claveX')"
MSG_CLAVE="$(intento "$ADMIN_USER" 'claveIncorrectaX9')"
printf "  Usuario inexistente : %s\n" "${MSG_USUARIO:-(sin mensaje)}"
printf "  Contraseña errónea  : %s\n" "${MSG_CLAVE:-(sin mensaje)}"
if [ -n "$MSG_USUARIO" ] && [ "$MSG_USUARIO" = "$MSG_CLAVE" ]; then
  ok "Los mensajes son idénticos (no permiten enumerar usuarios)"
else
  no "Los mensajes difieren (permiten confirmar nombres de usuario válidos)"
fi

echo
echo "== 4. Inicio de sesión legítimo (antes del bloqueo) =="
JAR="$(mktemp)"; curl -s -o /dev/null -c "$JAR" "$BASE/wp-login.php"
L="$(curl -s -o /dev/null -b "$JAR" -c "$JAR" -b 'wordpress_test_cookie=WP+Cookie+check' \
  --data-urlencode "log=$ADMIN_USER" --data-urlencode "pwd=$ADMIN_PASS" \
  --data 'wp-submit=Log+In&testcookie=1' -w '%{http_code}|%{redirect_url}' "$BASE/wp-login.php")"
if printf '%s' "$L" | grep -q '302.*/wp-admin/'; then ok "Credenciales válidas conceden acceso ($L)"; else no "El administrador no pudo iniciar sesión ($L)"; fi
rm -f "$JAR"

echo
echo "== 5. Límite de intentos (10 intentos fallidos consecutivos) =="
bloqueados=0
for i in $(seq 1 10); do
  m="$(intento "$ADMIN_USER" "claveMala_$i")"
  if printf '%s' "$m" | grep -qi 'demasiados intentos'; then
    bloqueados=$((bloqueados+1))
    [ "$bloqueados" = 1 ] && printf "  Bloqueo activado a partir del intento %d\n" "$i"
  fi
done
printf "  Intentos bloqueados: %d de 10\n" "$bloqueados"
if [ "$bloqueados" -gt 0 ]; then ok "El límite de intentos está activo"; else no "No hay límite de intentos (fuerza bruta ilimitada)"; fi

echo
echo "== 6. Recuperación tras limpiar el bloqueo =="
# En producción el bloqueo expira solo (15 min). Para dejar el entorno operativo
# se limpia el transitorio y se confirma que las credenciales válidas funcionan.
docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html \
  transient delete --all >/dev/null 2>&1 || true
JAR="$(mktemp)"; curl -s -o /dev/null -c "$JAR" "$BASE/wp-login.php"
L="$(curl -s -o /dev/null -b "$JAR" -c "$JAR" -b 'wordpress_test_cookie=WP+Cookie+check' \
  --data-urlencode "log=$ADMIN_USER" --data-urlencode "pwd=$ADMIN_PASS" \
  --data 'wp-submit=Log+In&testcookie=1' -w '%{http_code}' "$BASE/wp-login.php")"
if [ "$L" = 302 ]; then ok "Tras limpiar el bloqueo, el acceso legítimo se restablece"; else no "El acceso legítimo no se restableció (HTTP $L)"; fi
rm -f "$JAR"
