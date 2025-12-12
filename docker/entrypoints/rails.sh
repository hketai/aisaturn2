#!/bin/sh

set -e

echo "=== Rails Entrypoint Starting ==="

# Remove a potentially pre-existing server.pid for Rails.
rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/bootsnap*

echo "Waiting for postgres to become ready...."

# Let DATABASE_URL env take presedence over individual connection params.
# This is done to avoid printing the DATABASE_URL in the logs
$(docker/entrypoints/helpers/pg_database_url.rb) 2>/dev/null || true

# Set defaults if not provided
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USERNAME="${POSTGRES_USERNAME:-postgres}"

PG_READY="pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USERNAME"

until $PG_READY
do
  echo "Postgres is unavailable - sleeping..."
  sleep 2;
done

echo "Database ready to accept connections."

# Fix git hardlink issue on overlay filesystem (Docker overlay2 doesn't support hardlinks)
git config --global core.hardlinks false

# Install missing gems if needed
# This handles both development mode (with BUNDLE_WITHOUT="") and cases where gems are missing
if ! bundle check > /dev/null 2>&1; then
  echo "=== Running bundle install (this may take a while on first run) ==="
  
  # Clean corrupted git cache if exists (fixes "hardlink different from source" errors)
  if [ -d "/gems/ruby" ]; then
    rm -rf /gems/ruby/*/cache/bundler/git/* /gems/ruby/*/bundler/gems/* 2>/dev/null || true
  fi
  
  # Install gems with git clone protection disabled (needed for overlay filesystem)
  GIT_CLONE_PROTECTION_ACTIVE=false bundle install --jobs=4 --retry=3
  
  echo "=== Bundle install completed ==="
fi

# Final bundle check with retry
BUNDLE_CHECK_ATTEMPTS=0
MAX_ATTEMPTS=30

while ! bundle check > /dev/null 2>&1; do
  BUNDLE_CHECK_ATTEMPTS=$((BUNDLE_CHECK_ATTEMPTS + 1))
  if [ $BUNDLE_CHECK_ATTEMPTS -ge $MAX_ATTEMPTS ]; then
    echo "ERROR: Bundle check failed after $MAX_ATTEMPTS attempts"
    exit 1
  fi
  echo "Bundle check failed, retrying... ($BUNDLE_CHECK_ATTEMPTS/$MAX_ATTEMPTS)"
  sleep 2
done

echo "=== Bundle check passed, starting Rails ==="

# Execute the main process of the container
exec "$@"
