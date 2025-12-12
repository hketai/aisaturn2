#!/bin/sh
set -e

echo "=== Vite Entrypoint Starting ==="

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/bootsnap* 2>/dev/null || true

# Fix git hardlink issue on overlay filesystem
git config --global core.hardlinks false

# Install missing gems if needed
if ! bundle check > /dev/null 2>&1; then
  echo "=== Running bundle install ==="
  rm -rf /gems/ruby/*/cache/bundler/git/* /gems/ruby/*/bundler/gems/* 2>/dev/null || true
  GIT_CLONE_PROTECTION_ACTIVE=false bundle install --jobs=4 --retry=3
fi

# Wait for bundle to be ready
until bundle check > /dev/null 2>&1; do
  echo "Waiting for bundle..."
  sleep 2
done

# pnpm install if available
if command -v pnpm > /dev/null 2>&1; then
  pnpm store prune 2>/dev/null || true
  pnpm install --force
fi

echo "=== Ready to run Vite development server ==="

exec "$@"
