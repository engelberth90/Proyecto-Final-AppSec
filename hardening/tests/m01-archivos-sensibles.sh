#!/usr/bin/env bash
# =============================================================================
# M-01 - Verificación de exposición de archivos sensibles (hallazgo 2.3).
#
# Reproduce la prueba de concepto del informe de pentesting (solicitudes HTTP
# sin credenciales) y la amplía a otros archivos sensibles y a variantes que un
# atacante probaría ante un bloqueo por nombre exacto. Se ejecuta sin cambios
# antes y después de aplicar la mitigación.
#
# Uso:      bash hardening/tests/m01-archivos-sensibles.sh [URL_BASE]
# Criterio: un recurso se considera EXPUESTO si responde HTTP 200.
# =============================================================================

BASE="${1:-http://localhost:31338}"

RUTAS=(
  "/.env"                  # Reportado en el hallazgo 2.3
  "/wp-config.php.bak"     # Reportado en el hallazgo 2.3
  "/dump.sql"              # Reportado en el hallazgo 2.3
  "/.git/config"           # Reportado en el hallazgo 2.3
  "/.git/HEAD"
  "/debug.log"
  "/wp-content/debug.log"  # Ubicación por defecto de WP_DEBUG_LOG
  "/info.php"
  "/adminer.php"
  "/.htaccess"
  # Variantes habituales tras un bloqueo por nombre exacto
  "/wp-config.php~"
  "/wp-config.php.old"
  "/wp-config.php.save"
  "/backup.sql.gz"
  "/.env.backup"
)

expuestos=0
printf "%-26s %-6s %s\n" "RUTA" "HTTP" "RESULTADO"
printf "%-26s %-6s %s\n" "----" "----" "---------"
for r in "${RUTAS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE$r")
  if [ "$code" = "200" ]; then
    estado="EXPUESTO"; expuestos=$((expuestos+1))
  else
    estado="bloqueado/no existe"
  fi
  printf "%-26s %-6s %s\n" "$r" "$code" "$estado"
done
echo
echo "Total expuestos: $expuestos de ${#RUTAS[@]}"

# Control de regresión: el sitio debe seguir operativo tras la mitigación.
echo
for r in "/" "/wp-login.php" "/wp-content/plugins/wp-statistics/readme.txt"; do
  printf "Control funcional %-45s -> HTTP %s\n" "$r" "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$r")"
done
