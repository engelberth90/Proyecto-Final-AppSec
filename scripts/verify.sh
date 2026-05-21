#!/usr/bin/env bash
# wordpress-vulnerable-lab :: verify.sh
# Confirms that the expected vulnerable plugins/themes/files are reachable.
#
# Author: Ayi NEDJIMI
set -u
BASE="${1:-http://localhost:31338}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
fail() { echo -e "${RED}[KO]${NC} $*"; }
warn() { echo -e "${YEL}[!!]${NC} $*"; }

PASS=0; FAIL=0

check() {
  local label="$1" url="$2" expected="$3"
  local code
  code=$(curl --max-time 5 -s -o /dev/null -w '%{http_code}' "$url" || echo 000)
  if [[ ",${expected}," == *",${code},"* ]]; then
    ok  "$label -> $code"
    PASS=$((PASS+1))
  else
    fail "$label -> $code (wanted $expected) :: $url"
    FAIL=$((FAIL+1))
  fi
}

PLUGINS=(
  really-simple-ssl litespeed-cache wpforms-lite wp-statistics forminator
  ultimate-member mw-wp-form email-subscribers elementor contact-form-7
  essential-addons-for-elementor-lite wp-fastest-cache fluentform
  wp-google-maps royal-elementor-addons advanced-custom-fields popup-builder
  ninja-forms give user-registration loginpress ml-slider all-in-one-seo-pack
  duplicator wp-mail-smtp post-smtp lifterlms essential-blocks wp-cerber
  easy-digital-downloads user-role-editor all-in-one-wp-migration
  advanced-access-manager popup-maker translatepress-multilingual
  miniorange-saml-20-single-sign-on
)

echo "=== Plugin readme exposure ==="
for slug in "${PLUGINS[@]}"; do
  check "plugin:$slug" "$BASE/wp-content/plugins/$slug/readme.txt" "200,301"
done

echo ""
echo "=== Intentional info leaks ==="
check "phpinfo"          "$BASE/info.php"            "200"
check "adminer-bait"     "$BASE/adminer.php"         "200"
check "debug.log"        "$BASE/debug.log"           "200"
check "wp-config.bak"    "$BASE/wp-config.php.bak"   "200"
check "dump.sql"         "$BASE/dump.sql"            "200"
check ".env leak"        "$BASE/.env"                "200"
check ".git/HEAD"        "$BASE/.git/HEAD"           "200"
check ".git/config"      "$BASE/.git/config"         "200"
check "uploads index"    "$BASE/wp-content/uploads/" "200,403"

echo ""
echo "=== WordPress core fingerprints ==="
check "wp-login"         "$BASE/wp-login.php"       "200"
check "xmlrpc"           "$BASE/xmlrpc.php"         "200,405"
check "readme"           "$BASE/readme.html"        "200"
check "wp-cron"          "$BASE/wp-cron.php"        "200"
check "rest-api"         "$BASE/wp-json/"           "200"
check "user-enum"        "$BASE/wp-json/wp/v2/users" "200,401"

echo ""
echo "============================================================"
echo " RESULT: $PASS passed / $FAIL failed"
echo "============================================================"
exit $FAIL
