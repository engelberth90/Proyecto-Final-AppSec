#!/usr/bin/env bash
# plant-flags.sh — write CTF flags into the running lab.
# Author: Ayi NEDJIMI <ayinedjimi@users.noreply.github.com>
#
# Usage:
#   bash scripts/plant-flags.sh
#
# Requirements:
#   - docker compose stack up (wpvl-wordpress + db; aux stack for chain 4)
#   - wp-cli baked into the wordpress image (the lab Dockerfile installs it)

set -euo pipefail

FLAG1="FLAG{wpvulnlab-chain1-a1f3c9e2}"
FLAG2="FLAG{wpvulnlab-chain2-b7d2e8f4}"
FLAG3="FLAG{wpvulnlab-chain3-c4a9b1d6}"
FLAG4="FLAG{wpvulnlab-chain4-d8e5f2a3}"
FLAG5="FLAG{wpvulnlab-chain5-e2b6c4f9}"

WP_CT="${WP_CT:-wpvl-wordpress}"
MINIO_CT="${MINIO_CT:-wpvl-minio}"
DB_CT="${DB_CT:-wpvl-db}"
MC_ALIAS="${MC_ALIAS:-local}"
S3_BUCKET="${S3_BUCKET:-wp-backups}"

log() { printf '[plant-flags] %s\n' "$*"; }

wp() { docker exec -u www-data "$WP_CT" wp --path=/var/www/html "$@"; }

require_container() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${1}$"; then
    log "WARN: container '$1' is not running, skipping related plants"
    return 1
  fi
  return 0
}

############################################
# Chain 1: filesystem flag
############################################
plant_chain1() {
  require_container "$WP_CT" || return 0
  log "Chain 1 -> /flag-chain1.txt"
  docker exec -u root "$WP_CT" bash -c \
    "printf '%s\n' '$FLAG1' > /flag-chain1.txt && chown www-data:www-data /flag-chain1.txt && chmod 0644 /flag-chain1.txt"
}

############################################
# Chain 2: wp_options
############################################
plant_chain2() {
  require_container "$WP_CT" || return 0
  log "Chain 2 -> wp_options.ctf_flag_chain2"
  wp option update ctf_flag_chain2 "$FLAG2" --autoload=no >/dev/null
}

############################################
# Chain 3: wp_options + register REST exposure
############################################
plant_chain3() {
  require_container "$WP_CT" || return 0
  log "Chain 3 -> wp_options.ctf_flag_chain3 + REST setting"
  wp option update ctf_flag_chain3 "$FLAG3" --autoload=no >/dev/null

  # mu-plugin that registers the option in REST /wp/v2/settings
  docker exec -u root "$WP_CT" mkdir -p /var/www/html/wp-content/mu-plugins
  docker exec -u root "$WP_CT" bash -c "cat > /var/www/html/wp-content/mu-plugins/ctf-chain3-rest.php <<'PHP'
<?php
add_action('rest_api_init', function () {
    register_setting('options', 'ctf_flag_chain3', [
        'show_in_rest' => true,
        'type'         => 'string',
        'default'      => '',
    ]);
});
PHP"
  docker exec -u root "$WP_CT" chown -R www-data:www-data /var/www/html/wp-content/mu-plugins
}

############################################
# Chain 4: stuff flag in DB, then dump to S3
############################################
plant_chain4() {
  require_container "$WP_CT" || return 0
  log "Chain 4 -> wp_postmeta + MinIO backup"
  POST_ID=$(wp post list --post_type=post --format=ids | awk '{print $1}')
  if [ -z "$POST_ID" ]; then
    POST_ID=$(wp post create --post_title='ctf seed' --post_status=publish --porcelain)
  fi
  wp post meta update "$POST_ID" _ctf_flag_chain4 "$FLAG4" >/dev/null

  # Dump DB and push to MinIO if MinIO is running
  if require_container "$MINIO_CT"; then
    docker exec -u root "$WP_CT" bash -c \
      "wp --path=/var/www/html --allow-root db export /tmp/wp-dump.sql && gzip -f /tmp/wp-dump.sql"
    docker cp "$WP_CT":/tmp/wp-dump.sql.gz /tmp/wp-dump.sql.gz
    docker exec "$MINIO_CT" mc alias set $MC_ALIAS http://127.0.0.1:9000 minioadmin minioadmin >/dev/null 2>&1 || true
    docker exec "$MINIO_CT" mc mb -p $MC_ALIAS/$S3_BUCKET >/dev/null 2>&1 || true
    docker cp /tmp/wp-dump.sql.gz "$MINIO_CT":/tmp/wp-dump.sql.gz
    docker exec "$MINIO_CT" mc cp /tmp/wp-dump.sql.gz $MC_ALIAS/$S3_BUCKET/backups/wp-dump.sql.gz
    docker exec "$MINIO_CT" mc anonymous set download $MC_ALIAS/$S3_BUCKET >/dev/null 2>&1 || true
  else
    log "MinIO not running; chain-4 dump skipped (run docker-compose.aux.yml first)"
  fi
}

############################################
# Chain 5: stage a backdoor plugin zip + uploads canary
############################################
plant_chain5() {
  require_container "$WP_CT" || return 0
  log "Chain 5 -> backdoor plugin zip + uploads canary"

  # Canary file inside uploads (final-flag persistence marker)
  docker exec -u root "$WP_CT" bash -c \
    "mkdir -p /var/www/html/wp-content/uploads && printf '%s\n' '$FLAG5' > /var/www/html/wp-content/uploads/.ctf-chain5 && chown www-data:www-data /var/www/html/wp-content/uploads/.ctf-chain5"

  # Build backdoor plugin on host then expose at /tmp/c5/backdoor.zip
  STAGE=$(mktemp -d)
  mkdir -p "$STAGE/ctf-backdoor"
  cat > "$STAGE/ctf-backdoor/ctf-backdoor.php" <<PHP
<?php
/**
 * Plugin Name: CTF Backdoor (chain 5 marker)
 * Description: Returns the flag when ?ctf=flag is set. CTF use only.
 * Version: 1.0
 * Author: Ayi NEDJIMI
 */
add_action('init', function () {
    if (isset(\$_GET['ctf']) && \$_GET['ctf'] === 'flag') {
        header('Content-Type: text/plain');
        echo "$FLAG5\n";
        exit;
    }
});
PHP
  ( cd "$STAGE" && zip -qr backdoor.zip ctf-backdoor )
  mkdir -p /tmp/c5
  cp "$STAGE/backdoor.zip" /tmp/c5/backdoor.zip
  log "  -> /tmp/c5/backdoor.zip ready for chain-5 step 4"
  rm -rf "$STAGE"
}

main() {
  plant_chain1
  plant_chain2
  plant_chain3
  plant_chain4
  plant_chain5
  log "All flags planted."
}

main "$@"
