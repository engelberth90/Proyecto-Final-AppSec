#!/usr/bin/env bash
# =============================================================================
# M-01 - Aplicación de la mitigación de exposición de archivos sensibles
#        (hallazgo 2.3 del informe de pentesting).
#
# Uso:        bash hardening/apply/m01-archivos-sensibles.sh [DIRECTORIO_DEL_LAB]
# Requisitos: Docker Engine con Compose v2, permisos sobre el daemon de Docker
#             y el laboratorio en ejecución (contenedores wpvl-wordpress y wpvl-db).
#
# El script es idempotente. No modifica los archivos originales del laboratorio:
# el despliegue endurecido se levanta con hardening/src/docker-compose.yml.
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
COMPOSE=(docker compose --project-directory "$LAB" -f "$LAB/hardening/src/docker-compose.yml")
WP="wpvl-wordpress"
DB="wpvl-db"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-root}"   # Valor por defecto del laboratorio.

wpcli() { docker exec -u root "$WP" wp --path=/var/www/html --allow-root "$@"; }

echo "[1/5] Causa raíz: eliminación de archivos sensibles del webroot (volumen wp_data)"
docker exec "$WP" rm -rf \
  /var/www/html/.env /var/www/html/wp-config.php.bak /var/www/html/dump.sql \
  /var/www/html/.git /var/www/html/debug.log /var/www/html/info.php \
  /var/www/html/adminer.php /var/www/html/wp-content/debug.log

echo "[2/5] Depuración desactivada y log de WordPress fuera del webroot"
wpcli config set WP_DEBUG false --raw
wpcli config set WP_DEBUG_DISPLAY false --raw
wpcli config set WP_DEBUG_LOG /var/log/wordpress/debug.log

echo "[3/5] Rotación de la contraseña de base de datos expuesta"
# La contraseña nueva se guarda en $LAB/.env (permisos 600). Docker Compose lee
# ese archivo; Apache no lo sirve porque está fuera del webroot. El archivo está
# excluido del control de versiones (.gitignore) y del contexto de build (.dockerignore).
if ! grep -qs '^WP_DB_PASSWORD=' "$LAB/.env"; then
  ( umask 077; echo "WP_DB_PASSWORD=$(openssl rand -hex 24)" >> "$LAB/.env" )
fi
chmod 600 "$LAB/.env"
NEW_DB_PASSWORD="$(grep '^WP_DB_PASSWORD=' "$LAB/.env" | cut -d= -f2-)"
docker exec "$DB" mysql -uroot -p"$DB_ROOT_PASSWORD" -e \
  "ALTER USER 'wordpress'@'%' IDENTIFIED BY '$NEW_DB_PASSWORD'; FLUSH PRIVILEGES;" 2>/dev/null
wpcli config set DB_PASSWORD "$NEW_DB_PASSWORD" >/dev/null

echo "[4/5] Regeneración de llaves y salts de WordPress (invalida las sesiones abiertas)"
wpcli config shuffle-salts

echo "[5/5] Reconstrucción con la imagen y la configuración endurecidas"
"${COMPOSE[@]}" up -d --build wordpress db

for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:31338/ || true)
  [ "$code" = "200" ] && break
  sleep 2
done
echo "El sitio responde HTTP ${code}"
