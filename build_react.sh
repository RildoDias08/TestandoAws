#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "iniciando build..."

cd "$ROOT_DIR/client"
npm ci
npm run build

API_URL_VALUE="${API_URL:-}"

escape_json() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

ESCAPED_API_URL="$(escape_json "$API_URL_VALUE")"

cat > dist/config.js <<EOF_CONFIG
window.__CONFIG__ = {
  API_URL: "${ESCAPED_API_URL}"
};
EOF_CONFIG

echo "build finalizado"
