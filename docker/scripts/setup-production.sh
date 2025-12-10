#!/bin/bash
# Production Setup Script for CWAIS
# Bu script sunucuda ilk kurulum için kullanılır
# Kullanım: bash setup-production.sh

set -e

echo "=== CWAIS Production Setup ==="

# Check if .env exists
if [ ! -f ".env" ]; then
  echo "ERROR: .env dosyası bulunamadı!"
  echo "Lütfen .env dosyasını oluşturun veya .env.example dosyasını kopyalayın:"
  echo "  cp .env.example .env"
  echo "  nano .env  # değişkenleri düzenleyin"
  exit 1
fi

# Load .env file
set -a
source .env
set +a

# Set defaults
export POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
export POSTGRES_PORT="${POSTGRES_PORT:-5432}"
export POSTGRES_DATABASE="${POSTGRES_DATABASE:-chatwoot}"
export POSTGRES_USERNAME="${POSTGRES_USERNAME:-postgres}"

echo ""
echo "=== Step 1: Docker imajlarını build et ==="
docker compose -f docker-compose.production.yaml build --no-cache

echo ""
echo "=== Step 2: Servisleri başlat ==="
docker compose -f docker-compose.production.yaml up -d postgres redis

echo ""
echo "=== Step 3: Postgres hazır olana kadar bekle ==="
sleep 10
until docker compose -f docker-compose.production.yaml exec -T postgres pg_isready -U "$POSTGRES_USERNAME" -d "$POSTGRES_DATABASE"; do
  echo "Postgres bekleniyor..."
  sleep 2
done

echo ""
echo "=== Step 4: Rails ve Sidekiq'i başlat ==="
docker compose -f docker-compose.production.yaml up -d rails sidekiq whatsapp-web

echo ""
echo "=== Step 5: Rails hazır olana kadar bekle (60sn) ==="
echo "Rails container başlatılıyor ve bundle install yapılıyor..."
sleep 60

echo ""
echo "=== Step 6: Database migration ==="
docker compose -f docker-compose.production.yaml exec -T rails bundle exec rails db:prepare

echo ""
echo "=== Step 7: Kurulum tamamlandı ==="
echo ""
docker compose -f docker-compose.production.yaml ps
echo ""
echo "✅ Kurulum başarılı!"
echo ""
echo "Uygulama şu adreste çalışıyor: http://localhost:3000"
echo ""
echo "Logları görmek için:"
echo "  docker compose -f docker-compose.production.yaml logs -f rails"
echo ""

