#!/usr/bin/env bash
# =============================================================================
# M-08 - Aplicación de la mitigación de componentes desactualizados
#        (hallazgo 2.4 del informe de pentesting).
#
# Actualiza la plataforma completa a versiones con soporte:
#   - Imagen base: WordPress + PHP 8.3 + Apache recientes (Dockerfile endurecido).
#   - Núcleo de WordPress a la última versión.
#   - Todos los complementos y temas a su última versión.
#   - Oculta la versión de WordPress, PHP y Apache en las respuestas.
#
# Esta mitigación es la última de la serie: supera los pines de versión de
# M-05/M-06/M-07 (ninja-forms, wp-fastest-cache, ultimate-member), que quedan en
# su última versión. Con el núcleo actualizado, Ninja Forms y Ultimate Member se
# activan y las mitigaciones M-05 y M-07 quedan verificables en vivo.
#
# Uso: bash hardening/apply/m08-componentes-desactualizados.sh [DIRECTORIO_DEL_LAB]
# El script es idempotente.
# =============================================================================
set -euo pipefail

LAB="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
COMPOSE=(docker compose --project-directory "$LAB" -f "$LAB/hardening/src/docker-compose.yml")
WP="wpvl-wordpress"
wpc() { docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html --skip-plugins --skip-themes "$@"; }

echo "[1/7] Reconstrucción con la imagen base soportada (WordPress/PHP 8.3/Apache)"
"${COMPOSE[@]}" up -d --build wordpress
for _ in $(seq 1 40); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:31338/ || true)
  [ "$code" = "200" ] && break; sleep 3
done
echo "  sitio -> HTTP ${code}"

echo "[2/7] Actualización del núcleo de WordPress a la última versión"
wpc core update
wpc core update-db

echo "[3/7] Actualización de todos los complementos"
wpc plugin update --all || true
# Algunos complementos no se actualizan con 'plugin update' por una comprobación
# de requisitos; se fuerza la instalación de la última versión de los que queden.
for p in $(wpc plugin list --update=available --field=name 2>/dev/null); do
  wpc plugin install "$p" --force || true
done

echo "[3b/7] Eliminación de complementos retirados del repositorio y vulnerables"
# popup-builder (CVE-2023-6000) fue cerrado en WordPress.org: no recibe
# actualizaciones. Al no tener parche disponible y no ser necesario, se elimina.
for p in popup-builder; do
  if wpc plugin is-installed "$p" 2>/dev/null; then
    wpc plugin delete "$p" || true
  fi
done

echo "[4/7] Actualización de todos los temas"
wpc theme update --all || true
for t in $(wpc theme list --update=available --field=name 2>/dev/null); do
  wpc theme install "$t" --force || true
done

echo "[5/7] Despliegue del mu-plugin que oculta la versión de WordPress"
docker cp "$LAB/hardening/src/mu-plugins/m08-ocultar-version.php" \
  "$WP:/var/www/html/wp-content/mu-plugins/m08-ocultar-version.php"
docker exec "$WP" chown www-data:www-data /var/www/html/wp-content/mu-plugins/m08-ocultar-version.php

echo "[6/7] Activación de Ninja Forms y Ultimate Member (confirmación en vivo de M-05 y M-07)"
docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html \
  plugin activate ninja-forms ultimate-member || true

echo "[7/7] Purga de cachés"
docker exec -u root "$WP" php -d memory_limit=512M /usr/local/bin/wp --allow-root --path=/var/www/html cache flush >/dev/null 2>&1 || true

echo "Núcleo: $(wpc core version)"
docker exec "$WP" php -v | head -1
