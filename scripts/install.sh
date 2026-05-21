#!/usr/bin/env bash
#
# wordpress-vulnerable-lab :: install.sh
# Author: Ayi NEDJIMI
#
# 1. Boots docker compose
# 2. Waits for WordPress
# 3. Runs core install
# 4. Creates editor / subscriber users
# 5. Installs 36+ pinned vulnerable plugins
# 6. Installs vulnerable themes
# 7. Verifies HTTP exposure for each plugin readme
#
# Usage (from WSL):
#   bash scripts/install.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT"

CONTAINER="wpvl-wordpress"
WP_HOST_URL="http://localhost:31338"
WP_PATH="/var/www/html"

GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[1;33m'; BLU='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${BLU}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YEL}[!]${NC} $*"; }
err()  { echo -e "${RED}[-]${NC} $*"; }

# --- Boot stack ---
log "docker compose up -d"
docker compose up -d --build

# --- Wait for WP container HTTP ---
log "Waiting for WordPress on $WP_HOST_URL ..."
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$WP_HOST_URL" || echo 000)
  if [ "$code" = "200" ] || [ "$code" = "302" ] || [ "$code" = "301" ]; then
    ok "WordPress is up (HTTP $code)"
    break
  fi
  sleep 2
done

wp_cli() {
  docker exec -u root "$CONTAINER" wp --path="$WP_PATH" --allow-root "$@"
}

# --- Core install (idempotent) ---
if ! wp_cli core is-installed >/dev/null 2>&1; then
  log "Running wp core install"
  wp_cli core install \
    --url="$WP_HOST_URL" \
    --title="WordPress Vulnerable Lab" \
    --admin_user="admin" \
    --admin_password="admin" \
    --admin_email="admin@vuln.lab" \
    --skip-email
  ok "Core installed"
else
  warn "Core already installed — skipping"
fi

# Weak passwords for editor + subscriber
wp_cli user get editor >/dev/null 2>&1 || \
  wp_cli user create editor editor@vuln.lab --role=editor --user_pass="editor"
wp_cli user get subscriber >/dev/null 2>&1 || \
  wp_cli user create subscriber sub@vuln.lab --role=subscriber --user_pass="password123"

# --- Plugin matrix (slug|version|CVE) ---
PLUGINS=(
  "really-simple-ssl|7.0.5|CVE-2023-6961 (XSS)"
  "litespeed-cache|6.3.0.1|CVE-2024-28000 (PE)"
  "wpforms-lite|1.8.5.4|CVE-2024-0383 (XSS authd)"
  "wp-statistics|13.2.10|CVE-2024-2194 (SQLi)"
  "forminator|1.24.6|CVE-2024-28890 (AFU/RCE)"
  "ultimate-member|2.6.6|CVE-2023-3460 (PE -> admin)"
  "mw-wp-form|4.4.2|CVE-2023-6553 (LFI/upload)"
  "email-subscribers|5.7.13|CVE-2024-1071 (SQLi)"
  "elementor|3.5.5|CVE-2023-48777 (AFU authd)"
  "contact-form-7|5.7.5.1|CVE-2023-6449 (AFU)"
  "essential-addons-for-elementor-lite|5.7.1|CVE-2023-32243 (PE)"
  "wp-fastest-cache|1.2.1|CVE-2023-6063 (SQLi)"
  "fluentform|5.0.2|CVE-2023-26540 (Stored XSS)"
  "wp-google-maps|9.0.27|CVE-2024-1071-class SQLi"
  "royal-elementor-addons|1.3.78|CVE-2023-5360 (AFU/RCE)"
  "advanced-custom-fields|6.2.5|CVE-2024-31077 (XSS authd)"
  "popup-builder|4.2.3|CVE-2023-6000 (Stored XSS)"
  "ninja-forms|3.6.25|CVE-2023-37979 (Reflected XSS)"
  "give|2.24.0|CVE-2024-1207 (SQLi unauth)"
  "user-registration|3.0.2|CVE-2023-3342 (AFU/RCE)"
  "loginpress|3.0.2|CVE-2023-2466 (Stored XSS)"
  "ml-slider|3.50.0|CVE-2023-6378 (XSS)"
  "all-in-one-seo-pack|4.5.8|CVE-2023-39979 (PE)"
  "duplicator|1.5.7.1|CVE-2023-6114 (info disclosure)"
  "wp-mail-smtp|3.11.0|CVE-2024-1054 (info disclosure)"
  "post-smtp|2.8.7|CVE-2023-6875 (AB / account takeover)"
  "lifterlms|7.4.1|CVE-2024-1207-family (SQLi)"
  "essential-blocks|4.3.0|CVE-2024-2298 (Stored XSS)"
  "wp-cerber|9.5|CVE-2024-2697 (AB / logic)"
  "easy-digital-downloads|3.2.6|CVE-2024-1981 (SQLi)"
  "user-role-editor|4.64|CVE-2024-37255 (PE)"
  "all-in-one-wp-migration|7.78|CVE-2023-40004 (AB / IDOR)"
  "advanced-access-manager|6.9.18|CVE-2023-7228 (PE)"
  "popup-maker|1.18.0|CVE-2024-2544 (XSS)"
  "translatepress-multilingual|2.7.3|CVE-2024-1313 (Stored XSS)"
  "miniorange-saml-20-single-sign-on|5.0.7|CVE-2024-2879 (XML AB class)"
  # Extra coverage on top of dvwp-extend baseline:
  "wp-file-manager|7.0|CVE-2020-25213 (legacy unauth RCE class)"
  "backup-migration|1.3.6|CVE-2023-6553 (BackupBuddy / Backup Migration unauth RCE)"
  "woocommerce|7.0.0|CVE-2023-28121 (Auth bypass)"
  # --- Phase A additions: 2024-2025 published CVE coverage ---
  "wp-automatic|3.92.0|CVE-2024-27956 (Unauth SQLi -> admin creation)"
  "masterstudy-lms-learning-management-system|3.2.5|CVE-2024-1512 (BAC / PE)"
  "fluent-smtp|2.2.80|CVE-2024-9511 (Broken Access Control)"
  "otter-blocks|2.6.4|CVE-2024-2226 (Stored XSS)"
  "nextend-facebook-connect|3.1.12|CVE-2024-1775 (Auth bypass)"
  "download-manager|3.2.98|CVE-2024-8284 (LFI / IDOR)"
  "wp-ultimate-csv-importer|7.20.0|CVE-2025-2007 (Arbitrary File Upload -> RCE)"
  "mailpoet|5.5.1|CVE-2024-12743 (Stored XSS)"
  "wp-job-manager|2.2.0|CVE-2024-34549 (Broken Access Control)"
  "seo-by-rank-math|1.0.228|CVE-2024-9161 (Open Redirect / SSRF)"
  "jetpack|13.8|CVE-2024-9926 (Broken Access Control)"
  "wp-recall|16.26.5|CVE-2024-32709 (SQLi)"
  "wp-time-capsule|1.22.20|CVE-2024-38770 (Deserialization)"
  "ws-form|1.9.243|CVE-2024-47320 (Stored XSS)"
  "simple-membership|4.4.1|CVE-2024-22308 (Auth bypass)"
)

TOTAL=${#PLUGINS[@]}
SUCCESS=0; SKIPPED=0; FAILED=0
INSTALLED_LIST=(); FAILED_LIST=()

install_plugin() {
  local slug="$1" ver="$2"
  if wp_cli plugin is-installed "$slug" >/dev/null 2>&1; then
    local cur; cur=$(wp_cli plugin get "$slug" --field=version 2>/dev/null || true)
    wp_cli plugin activate "$slug" >/dev/null 2>&1 || true
    warn "$slug already installed ($cur)"
    SKIPPED=$((SKIPPED+1)); INSTALLED_LIST+=("$slug|$cur|already")
    return 0
  fi
  log "Install $slug @ $ver"
  if wp_cli plugin install "$slug" --version="$ver" --activate --force >/tmp/wpcli.out 2>&1; then
    ok "wp-cli ok: $slug $ver"
    SUCCESS=$((SUCCESS+1)); INSTALLED_LIST+=("$slug|$ver|wp-cli")
    return 0
  fi
  warn "wp-cli failed for $slug $ver — trying direct ZIP"
  local url="https://downloads.wordpress.org/plugin/${slug}.${ver}.zip"
  local tmp="/tmp/${slug}-${ver}.zip"
  if docker exec "$CONTAINER" bash -c "curl -fsSL --max-time 30 '$url' -o '$tmp'"; then
    if wp_cli plugin install "$tmp" --activate --force >>/tmp/wpcli.out 2>&1; then
      ok "ZIP fallback ok: $slug $ver"
      SUCCESS=$((SUCCESS+1)); INSTALLED_LIST+=("$slug|$ver|zip")
      return 0
    fi
  fi
  err "Failed: $slug $ver"
  FAILED=$((FAILED+1)); FAILED_LIST+=("$slug|$ver")
  return 1
}

declare -A SEEN
for entry in "${PLUGINS[@]}"; do
  slug=$(echo "$entry" | awk -F'|' '{print $1}')
  ver=$(echo "$entry"  | awk -F'|' '{print $2}')
  [ -n "${SEEN[$slug]:-}" ] && continue
  SEEN[$slug]=1
  install_plugin "$slug" "$ver" || true
done

# --- Themes ---
log "Installing vulnerable themes"
wp_cli theme install twentyeleven --force >/dev/null 2>&1 || true
wp_cli theme install twentyfifteen --force >/dev/null 2>&1 || true
wp_cli theme install twentyseventeen --force >/dev/null 2>&1 || true

# Phase A: 5 vulnerable themes pinned to known-vulnerable 2024-2025 CVE versions.
# Only one is activated to avoid layout conflicts; the rest stay installed-but-inactive
# (still detectable by scanners via /wp-content/themes/<slug>/style.css fingerprinting).
THEMES=(
  "hello-elementor|3.0.0|CVE-2024-31289"
  "astra|4.6.8|CVE-2024-2347"
  "blocksy|2.0.40|CVE-2024-3747"
  "oceanwp|3.5.4|CVE-2024-2476"
  "hestia|3.1.2|CVE-2024-37467"
)

install_theme() {
  local slug="$1" ver="$2"
  if wp_cli theme is-installed "$slug" >/dev/null 2>&1; then
    warn "theme $slug already installed"
    return 0
  fi
  log "Install theme $slug @ $ver"
  if wp_cli theme install "$slug" --version="$ver" --force >/tmp/wpcli.out 2>&1; then
    ok "theme wp-cli ok: $slug $ver"
    return 0
  fi
  warn "wp-cli theme install failed for $slug $ver — trying direct ZIP"
  local url="https://downloads.wordpress.org/theme/${slug}.${ver}.zip"
  local tmp="/tmp/${slug}-${ver}.zip"
  if docker exec "$CONTAINER" bash -c "curl -fsSL --max-time 30 '$url' -o '$tmp'"; then
    if wp_cli theme install "$tmp" --force >>/tmp/wpcli.out 2>&1; then
      ok "theme ZIP fallback ok: $slug $ver"
      return 0
    fi
  fi
  err "Failed theme: $slug $ver"
  return 1
}

for entry in "${THEMES[@]}"; do
  tslug=$(echo "$entry" | awk -F'|' '{print $1}')
  tver=$(echo "$entry"  | awk -F'|' '{print $2}')
  install_theme "$tslug" "$tver" || true
done

# Activate only hello-elementor (Phase A vulnerable theme of record).
wp_cli theme activate hello-elementor >/dev/null 2>&1 \
  || wp_cli theme activate twentyeleven >/dev/null 2>&1 || true

# --- Mailhog SMTP wiring ---
log "Wiring SMTP to MailHog"
wp_cli option update wp_mail_smtp '{"mail":{"mailer":"smtp"},"smtp":{"host":"mailhog","port":1025,"encryption":"none","auth":false}}' --format=json >/dev/null 2>&1 || true

# --- Report ---
echo "============================================================"
echo " FINAL REPORT"
echo "============================================================"
echo "Total entries     : $TOTAL"
echo "Newly installed   : $SUCCESS"
echo "Already present   : $SKIPPED"
echo "Failed            : $FAILED"
echo ""
echo "WordPress       -> http://localhost:31338"
echo "phpMyAdmin      -> http://localhost:31339"
echo "MailHog UI      -> http://localhost:31340"
echo "Adminer         -> http://localhost:31341"
echo ""
echo "Credentials:"
echo "  admin / admin       (administrator)"
echo "  editor / editor     (editor)"
echo "  subscriber / password123  (subscriber)"
