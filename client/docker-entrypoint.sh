#!/bin/sh
set -e

cat > /usr/share/nginx/html/config.js <<EOF
window.__CONFIG__ = {
  API_URL: "${API_URL:-}"
};
EOF

exec "$@"
