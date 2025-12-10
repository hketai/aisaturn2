#!/bin/bash
# Production Update Script for CWAIS
# Bu script sunucuda güncelleme için kullanılır
# Kullanım: bash update-production.sh

set -e

echo "=== CWAIS Production Update ==="

# Load .env file
set -a
source .env
set +a

echo ""
echo "=== Step 1: Servisleri durdur ==="
docker compose -f docker-compose.production.yaml stop rails sidekiq

echo ""
echo "=== Step 2: Imajları yeniden build et ==="
docker compose -f docker-compose.production.yaml build

echo ""
echo "=== Step 3: Servisleri başlat ==="
docker compose -f docker-compose.production.yaml up -d rails sidekiq whatsapp-web

echo ""
echo "=== Step 4: Rails hazır olana kadar bekle ==="
sleep 30

echo ""
echo "=== Step 5: Database migration ==="
docker compose -f docker-compose.production.yaml exec -T rails bundle exec rails db:migrate || true

echo ""
echo "=== Step 6: Güncelleme tamamlandı ==="
echo ""
docker compose -f docker-compose.production.yaml ps
echo ""
echo "✅ Güncelleme başarılı!"
echo ""

