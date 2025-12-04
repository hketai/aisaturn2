#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

# Install bundler 2.5.11 if not present (required by bin/vite)
if ! gem list bundler -i -v "2.5.11" >/dev/null 2>&1; then
  gem install bundler -v "2.5.11" || true
fi

pnpm store prune
pnpm install --force

echo "Ready to run Vite development server."

exec "$@"
