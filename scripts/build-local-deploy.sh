#!/usr/bin/env bash
# Build Flutter web + assemble local_deploy for LAN testing.
# App URL: http://10.40.102.69:8080/em/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/fleet_em_dashboard"
HOSTING="$ROOT/hosting/em"
OUT="$ROOT/local_deploy"
HOST="10.40.102.69"
PORT="8080"
BASE_URL="http://${HOST}:${PORT}"
APP_URL="${BASE_URL}/em"

echo "==> Flutter build web (base: /em/, API: ${APP_URL}/api)"
cd "$APP"
MSYS_NO_PATHCONV=1 flutter build web --base-href=/em/ \
  --dart-define=FLEET_HOST_BASE="${APP_URL}" \
  --dart-define=FLEET_UPLOAD_URL="${APP_URL}/api/upload.php" \
  --dart-define=FLEET_CURRENT_URL="${APP_URL}/api/current.php" \
  --dart-define=FLEET_UPLOAD_TOKEN=fleet-em-change-me

echo "==> Assemble ${OUT}"
rm -rf "$OUT"
mkdir -p "$OUT/em/data/list1"

cp -r "$APP/build/web/." "$OUT/em/"
cp -r "$HOSTING/api" "$OUT/em/"
cp -r "$HOSTING/sql" "$OUT/em/" 2>/dev/null || true
cp "$HOSTING/data/list1/.htaccess" "$OUT/em/data/list1/" 2>/dev/null || true
touch "$OUT/em/data/list1/.gitkeep"

echo ""
echo "Done. Start server:"
echo "  bash scripts/start-local-server.sh"
echo "Open: ${APP_URL}/"
echo ""
echo "MySQL: import ${HOSTING}/sql/schema.sql (db_em / tb_list1)"
