#!/usr/bin/env bash
# PHP built-in server: Flutter app + API on one port.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/local_deploy"
HOST="10.40.102.69"
PORT="8080"

if [[ ! -d "$OUT" ]]; then
  echo "Folder local_deploy belum ada. Jalankan dulu: bash scripts/build-local-deploy.sh"
  exit 1
fi

find_php() {
  if command -v php >/dev/null 2>&1; then
    command -v php
    return 0
  fi
  local candidates=(
    "/c/xampp/php/php.exe"
    "/d/xampp/php/php.exe"
    "/c/laragon/bin/php/php-8.3.0-Win32-vs16-x64/php.exe"
    "/c/Program Files/php/php.exe"
  )
  for c in "${candidates[@]}"; do
    if [[ -x "$c" ]]; then
      echo "$c"
      return 0
    fi
  done
  return 1
}

PHP_BIN="$(find_php || true)"

if [[ -z "$PHP_BIN" ]]; then
  echo "PHP tidak ditemukan — hanya file statis (upload API tidak jalan)."
  echo "Install XAMPP/Laragon atau tambahkan php ke PATH."
  echo ""
  if command -v python >/dev/null 2>&1; then
    echo "Fallback: python http.server (tanpa PHP)"
    echo "Open: http://${HOST}:${PORT}/em/"
    cd "$OUT"
    exec python -m http.server "$PORT" --bind "$HOST"
  fi
  echo "Tidak ada python/php. Install salah satu lalu coba lagi."
  exit 1
fi

echo "PHP: $PHP_BIN"
echo "Serving ${OUT}"
echo "Open: http://${HOST}:${PORT}/em/"
echo "API:  http://${HOST}:${PORT}/em/api/current.php"
echo "Ctrl+C to stop."
cd "$OUT"
exec "$PHP_BIN" -S "${HOST}:${PORT}"
