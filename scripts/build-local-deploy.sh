#!/usr/bin/env bash
# Build Flutter web + assemble local_deploy for LAN testing.
# App URL: http://10.40.102.69:8080/em/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/fleet_em_dashboard"
HOSTING="$ROOT/hosting/em"
OUT="$ROOT/local_deploy"
ACTIVE_LIST="${1:-list2}"
HOST="10.40.102.69"
PORT="8080"
BASE_URL="http://${HOST}:${PORT}"
APP_URL="${BASE_URL}/em"

echo "==> Flutter build web (base: /em/, API: ${APP_URL}/api)"
cd "$APP"
MSYS_NO_PATHCONV=1 flutter build web --base-href=/em/ \
  --dart-define=FLEET_HOST_BASE="${APP_URL}" \
  --dart-define=FLEET_ACTIVE_LIST="${ACTIVE_LIST}" \
  --dart-define=FLEET_UPLOAD_URL="${APP_URL}/api/upload.php" \
  --dart-define=FLEET_CURRENT_URL="${APP_URL}/api/current.php" \
  --dart-define=FLEET_UPLOAD_URL_LIST2="${APP_URL}/api/upload_list2.php" \
  --dart-define=FLEET_CURRENT_URL_LIST2="${APP_URL}/api/current_list2.php" \
  --dart-define=FLEET_UPLOAD_TOKEN=fleet-em-change-me

echo "==> Assemble ${OUT}"
rm -rf "$OUT"
mkdir -p "$OUT/em/data/list1" "$OUT/em/data/list2"

cp -r "$APP/build/web/." "$OUT/em/"
cp -r "$HOSTING/api" "$OUT/em/"
cp -r "$HOSTING/sql" "$OUT/em/" 2>/dev/null || true
cp "$HOSTING/data/list1/.htaccess" "$OUT/em/data/list1/" 2>/dev/null || true
cp "$HOSTING/data/list2/.htaccess" "$OUT/em/data/list2/" 2>/dev/null || true
touch "$OUT/em/data/list1/.gitkeep"
touch "$OUT/em/data/list2/.gitkeep"

echo ""
echo "Done. Start server:"
echo "  bash scripts/start-local-server.sh"
echo "Open: ${APP_URL}/"
echo "Active list: ${ACTIVE_LIST}"
echo ""
echo "MySQL: import ${HOSTING}/sql/schema.sql (db_em / tb_list1 + tb_list2)"
