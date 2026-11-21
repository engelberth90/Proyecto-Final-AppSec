#!/usr/bin/env bash
# =============================================================================
# M-04 - Aplicación de la mitigación de fuerza bruta mediante XML-RPC
#        (hallazgo 2.2 del informe de pentesting).
#
# Uso:        bash hardening/apply/m04-fuerza-bruta.sh [DIRECTORIO_DEL_LAB]
# Requisitos: M-01, M-02 y M-03 aplicadas y el laboratorio en ejecución.
#
# El script es idempotente.
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
COMPOSE=(docker compose --project-directory "$LAB" -f "$LAB/hardening/src/docker-compose.yml")
WP="wpvl-wordpress"
MU_ORIGEN="$LAB/hardening/src/mu-plugins/m04-fuerza-bruta.php"
MU_DESTINO="/var/www/html/wp-content/mu-plugins/m04-fuerza-bruta.php"
wpcli() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --path=/var/www/html --allow-root "$@"; }

echo "[1/4] Instalación del mu-plugin de protección contra fuerza bruta"
docker cp "$MU_ORIGEN" "$WP:$MU_DESTINO"
docker exec "$WP" chown www-data:www-data "$MU_DESTINO"
docker exec "$WP" php -l "$MU_DESTINO"

echo "[2/4] Asignación de contraseñas robustas y registro en .env (fuera del webroot)"
# Las contraseñas débiles (admin/admin, editor/editor, subscriber/password123)
# eran triviales de adivinar. Se sustituyen por valores aleatorios y se guardan
# en el .env del proyecto, que no se sirve por HTTP ni se incluye en el control
# de versiones. Las pruebas los leen mediante hardening/tests/lib-credenciales.sh.
touch "$LAB/.env"; chmod 600 "$LAB/.env"
fijar_clave() {   # fijar_clave LOGIN VARIABLE_ENV
  local login="$1" var="$2" clave
  clave="$(openssl rand -hex 20)"
  wpcli user update "$login" --user_pass="$clave" >/dev/null
  # Reemplaza o añade la variable en .env.
  if grep -q "^$var=" "$LAB/.env"; then
    sed -i "s|^$var=.*|$var=$clave|" "$LAB/.env"
  else
    echo "$var=$clave" >> "$LAB/.env"
  fi
  echo "  $login: contraseña actualizada ($var en .env)"
}
fijar_clave admin      WP_ADMIN_PASS
fijar_clave editor     WP_EDITOR_PASS
fijar_clave subscriber WP_SUB_PASS

echo "[3/4] Reconstrucción con la regla de Apache que bloquea xmlrpc.php"
"${COMPOSE[@]}" up -d --build wordpress

echo "[4/4] Validación de la configuración de Apache"
docker exec "$WP" apache2ctl -t

for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:31338/ || true)
  [ "$code" = "200" ] && break
  sleep 2
done
echo "El sitio responde HTTP ${code}"
echo "Las contraseñas nuevas quedaron en $LAB/.env"
