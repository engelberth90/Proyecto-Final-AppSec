#!/usr/bin/env bash
# =============================================================================
# M-02 - Aplicación de la mitigación del listado de directorios
#        (hallazgo 2.8 del informe de pentesting).
#
# Uso:        bash hardening/apply/m02-directory-listing.sh [DIRECTORIO_DEL_LAB]
# Requisitos: M-01 aplicada (el despliegue endurecido usa el archivo .env que
#             genera M-01) y el laboratorio en ejecución.
#
# El script es idempotente.
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
COMPOSE=(docker compose --project-directory "$LAB" -f "$LAB/hardening/src/docker-compose.yml")
WP="wpvl-wordpress"

echo "[1/3] Causa raíz: Options +Indexes -> -Indexes en el .htaccess del sitio"
# El .htaccess reside en el volumen wp_data y conserva los bloques que agregan
# los complementos (p. ej. LiteSpeed Cache); por eso se corrige la directiva en
# el archivo existente en lugar de reemplazarlo.
docker exec "$WP" sed -i -E 's/^(\s*Options\s+.*)\+Indexes/\1-Indexes/' /var/www/html/.htaccess
docker exec "$WP" grep -nE '^\s*Options' /var/www/html/.htaccess

echo "[2/3] Reconstrucción con Indexes retirado y mod_autoindex deshabilitado"
"${COMPOSE[@]}" up -d --build wordpress

echo "[3/3] Validación de la configuración de Apache"
docker exec "$WP" apache2ctl -t
docker exec "$WP" sh -c 'apache2ctl -M 2>/dev/null | grep -q autoindex && echo "mod_autoindex: habilitado" || echo "mod_autoindex: deshabilitado"'

for _ in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:31338/ || true)
  [ "$code" = "200" ] && break
  sleep 2
done
echo "El sitio responde HTTP ${code}"
