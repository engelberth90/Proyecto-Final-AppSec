#!/usr/bin/env bash
# wordpress-vulnerable-lab :: benchmark.sh
# Runs popular scanners against the lab and dumps reports.
#
# Author: Ayi NEDJIMI
set -u
BASE="${1:-http://localhost:31338}"
OUT="${2:-./bench-out}"
mkdir -p "$OUT"

echo "[*] BAZOOKA"
if command -v wordpress-bazooka >/dev/null 2>&1; then
  wordpress-bazooka -u "$BASE" -o "$OUT/bazooka.json" || true
else
  echo "    not installed: pip install wordpress-bazooka  (see https://github.com/ayinedjimi/wordpress-bazooka)"
fi

echo "[*] WPScan"
if command -v wpscan >/dev/null 2>&1; then
  wpscan --url "$BASE" --random-user-agent --no-update -e ap,t,u --format json -o "$OUT/wpscan.json" || true
else
  docker run --rm wpscanteam/wpscan --url "$BASE" --random-user-agent --no-update -e ap,t,u --format json > "$OUT/wpscan.json" || true
fi

echo "[*] Nuclei (wordpress templates)"
if command -v nuclei >/dev/null 2>&1; then
  nuclei -u "$BASE" -tags wordpress,wp -severity low,medium,high,critical -j -o "$OUT/nuclei.jsonl" || true
else
  echo "    nuclei not installed"
fi

echo "[*] Done. Reports in: $OUT"
