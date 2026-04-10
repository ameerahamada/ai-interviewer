#!/usr/bin/env bash
# Cloudflare Workers Static Assets build step.
# Assembles a clean public/ folder that the Worker will serve, and injects
# the real SHEET_WEBHOOK_URL from the environment variable configured in
# the Cloudflare dashboard (Settings → Variables and Secrets).

set -euo pipefail

echo "→ Preparing public/ directory"
rm -rf public
mkdir -p public

cp index.html public/index.html
cp README.md public/README.md

if [ -n "${SHEET_WEBHOOK_URL:-}" ]; then
  # Escape sed metacharacters in the URL
  ESCAPED=$(printf '%s\n' "$SHEET_WEBHOOK_URL" | sed -e 's/[\/&]/\\&/g')
  sed -i "s|YOUR_APPS_SCRIPT_WEB_APP_URL_HERE|$ESCAPED|" public/index.html
  echo "✓ Injected SHEET_WEBHOOK_URL into public/index.html"
else
  echo "⚠  SHEET_WEBHOOK_URL env var not set — placeholder remains."
  echo "   Set it under Cloudflare Dashboard → Worker → Settings → Variables and Secrets."
fi

# Safety check: the real GEMINI_API_KEY must never end up in the built output.
if grep -q 'AIzaSy' public/index.html; then
  echo "✗ SAFETY STOP: public/index.html contains a Gemini API key — refusing to deploy." >&2
  exit 1
fi

echo "✓ Build complete. Files in public/:"
ls -la public/
