#!/usr/bin/env bash
# =============================================================================
# Carga de credenciales de prueba.
#
# Las pruebas no contienen contraseñas. Se toman, en este orden, de:
#   1. variables de entorno ya definidas (ADMIN_USER, ADMIN_PASS, ...);
#   2. el archivo .env de la raíz del proyecto (generado por M-01 y M-04,
#      excluido del control de versiones);
#   3. los valores por defecto del laboratorio sin mitigar.
#
# Uso: source "$(dirname "$0")/lib-credenciales.sh"
# =============================================================================

_RAIZ_LAB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [ -r "$_RAIZ_LAB/.env" ]; then
  while IFS='=' read -r _clave _valor; do
    case "$_clave" in
      WP_ADMIN_PASS)  : "${ADMIN_PASS:=$_valor}" ;;
      WP_EDITOR_PASS) : "${EDITOR_PASS:=$_valor}" ;;
      WP_SUB_PASS)    : "${SUB_PASS:=$_valor}" ;;
    esac
  done < "$_RAIZ_LAB/.env"
fi

: "${ADMIN_USER:=admin}"      ; : "${ADMIN_PASS:=admin}"
: "${EDITOR_USER:=editor}"    ; : "${EDITOR_PASS:=editor}"
: "${SUB_USER:=subscriber}"   ; : "${SUB_PASS:=password123}"
