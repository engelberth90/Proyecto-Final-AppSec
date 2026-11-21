#!/usr/bin/env bash
# =============================================================================
# M-02 - Verificación del listado de directorios (hallazgo 2.8).
#
# Fase 1 (caja negra): reproduce la prueba de concepto del informe sobre los
#   directorios señalados por WPScan y el pentesting.
# Fase 2 (caja gris): obtiene del contenedor la lista completa de directorios
#   del webroot y solicita cada uno por HTTP. Un directorio se considera
#   EXPUESTO si la respuesta es un índice generado por Apache ("Index of").
#
# Se ejecuta sin cambios antes y después de aplicar la mitigación.
#
# Uso: bash hardening/tests/m02-directory-listing.sh [URL_BASE] [CONTENEDOR]
# =============================================================================

BASE="${1:-http://localhost:31338}"
WP="${2:-wpvl-wordpress}"
WEBROOT="/var/www/html"

es_listado() {
  curl -s --max-time 10 "$1" | grep -q '<title>Index of '
}

echo "== Fase 1: directorios reportados en el pentesting =="
printf "%-55s %s\n" "RUTA" "RESULTADO"
for r in "/wp-content/plugins/wp-statistics/" \
         "/wp-content/plugins/woocommerce/" \
         "/wp-content/plugins/wp-statistics/assets/" \
         "/wp-content/plugins/woocommerce/includes/"; do
  if es_listado "$BASE$r"; then estado="LISTADO EXPUESTO"; else estado="sin listado"; fi
  printf "%-55s %s\n" "$r" "$estado"
done

echo
echo "== Fase 2: barrido completo del webroot =="
# Se solicitan los directorios que no contienen archivo índice: son los únicos
# en los que Apache puede generar un listado. Todas las solicitudes se envían
# desde un único proceso curl que reutiliza la conexión (keep-alive), para no
# agotar los puertos efímeros del cliente con miles de conexiones nuevas.
LISTA="$(mktemp)"; CFG="$(mktemp)"; RES="$(mktemp)"
docker exec "$WP" sh -c "find '$WEBROOT' -type d | while read -r d; do
  [ -e \"\$d/index.php\" ] || [ -e \"\$d/index.html\" ] || [ -e \"\$d/index.htm\" ] || echo \"\${d#$WEBROOT}/\"
done" | sort > "$LISTA"
total=$(wc -l < "$LISTA")

while read -r d; do
  printf 'url = "%s%s"\noutput = "/dev/null"\n' "$BASE" "$d"
done < "$LISTA" > "$CFG"
curl -s --max-time 30 -K "$CFG" -w '%{http_code} %{url_effective}\n' > "$RES"

# 200 en un directorio sin índice = Apache generó el listado.
expuestos=$(awk '$1=="200"' "$RES" | wc -l)
bloqueados=$(awk '$1=="403" || $1=="404"' "$RES" | wc -l)
errores=$(awk '$1!="200" && $1!="403" && $1!="404"' "$RES" | wc -l)

echo "Directorios sin archivo índice    : $total"
echo "Con listado expuesto (HTTP 200)   : $expuestos"
echo "Sin listado (HTTP 403/404)        : $bloqueados"
echo "Sin respuesta válida (otros/000)  : $errores"
if [ "$expuestos" -gt 0 ]; then
  echo "Muestra (primeros 10):"
  awk '$1=="200"{print "  "$2}' "$RES" | sed "s#$BASE##" | head -10
  muestra=$(awk '$1=="200"{print $2; exit}' "$RES")
  if es_listado "$muestra"; then
    echo "Confirmación de contenido: $muestra devuelve una página 'Index of'"
  fi
fi
rm -f "$LISTA" "$CFG" "$RES"

echo
echo "== Control de regresión =="
for r in "/" "/wp-login.php" "/wp-content/plugins/wp-statistics/readme.txt" \
         "/wp-includes/js/jquery/jquery.js"; do
  printf "%-50s -> HTTP %s\n" "$r" "$(curl -s -o /dev/null -w '%{http_code}' "$BASE$r")"
done
echo "Respuesta HTTP a un directorio sin índice: $(curl -s -o /dev/null -w '%{http_code}' "$BASE/wp-content/plugins/wp-statistics/")"
