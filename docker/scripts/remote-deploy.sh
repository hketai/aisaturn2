#!/bin/bash
# Remote Deploy Script - Bu dosya sunucuya /root/deploy.sh olarak kopyalanmalı
# Kullanım: /root/deploy.sh

set -e

CWAIS_PATH="/root/cwais"
COMPOSE_FILE="docker-compose.production.yaml"
LOG_FILE="/tmp/cwais-deploy.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo "=========================================="
echo "CWAIS Production Deploy - $(date)"
echo "=========================================="
echo ""

cd "$CWAIS_PATH"

# Load .env
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

echo "=== Step 1: Build Docker images ==="
docker compose -f "$COMPOSE_FILE" build

echo ""
echo "=== Step 2: Stop rails and sidekiq ==="
docker compose -f "$COMPOSE_FILE" stop rails sidekiq || true

echo ""
echo "=== Step 3: Start all services ==="
docker compose -f "$COMPOSE_FILE" up -d

echo ""
echo "=== Step 4: Wait for Rails to be ready ==="
sleep 30

echo ""
echo "=== Step 5: Run database migrations ==="
docker compose -f "$COMPOSE_FILE" exec -T rails bundle exec rails db:migrate || {
  echo "Migration failed, trying db:prepare..."
  docker compose -f "$COMPOSE_FILE" exec -T rails bundle exec rails db:prepare
}

echo ""
echo "=== Step 6: Verify services ==="
docker compose -f "$COMPOSE_FILE" ps

echo ""
echo "=========================================="
echo "✅ Deploy completed at $(date)"
echo "=========================================="
echo ""
echo "Check logs: docker compose -f $COMPOSE_FILE logs -f rails"
echo ""

