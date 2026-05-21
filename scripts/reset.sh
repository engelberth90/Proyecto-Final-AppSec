#!/usr/bin/env bash
# wordpress-vulnerable-lab :: reset.sh
# Tear down volumes and rebuild from scratch.
#
# Author: Ayi NEDJIMI
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/.."

echo "[*] Stopping stack and removing volumes ..."
docker compose down -v

echo "[*] Re-running install.sh"
bash "$HERE/install.sh"
