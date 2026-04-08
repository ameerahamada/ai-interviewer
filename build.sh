#!/usr/bin/env bash
# Cloudflare Pages build step.
# Replaces the SHEET_WEBHOOK_URL placeholder in index.html with the value
# from the SHEET_WEBHOOK_URL environment variable set in the Pages dashboard.
# If the env var is missing, the placeholder stays — the site still loads,
# but sheet submissions will fail with an obvious message.

set -euo pipefail

if [ -z "${SHEET_WEBHOOK_URL:-}" ]; then
  echo "⚠  SHEET_WEBHOOK_URL env var not set — skipping injection."
  echo "   Sheet submissions will not work on this deployment."
  exit 0
fi

# Escape slashes and ampersands for sed
ESCAPED=$(printf '%s\n' "$SHEET_WEBHOOK_URL" | sed -e 's/[\/&]/\\&/g')

sed -i "s|YOUR_APPS_SCRIPT_WEB_APP_URL_HERE|$ESCAPED|" index.html

echo "✓ Injected SHEET_WEBHOOK_URL into index.html"
