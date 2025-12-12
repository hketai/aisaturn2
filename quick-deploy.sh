#!/bin/bash
# CWAIS Quick Deploy Script - Docker build yapmadan hızlı deploy
# Kullanım: ./quick-deploy.sh

set -e

SERVER="root@185.87.120.201"
PASSWORD="219zHm3d!"
REMOTE_PATH="/root/cwais"
LOCAL_PATH="/Users/harun/Desktop/PROJECTS/cwais"

echo "⚡ Quick Deploy başlıyor..."

# 1. Local'de frontend build yap
echo "🔨 Local'de frontend build yapılıyor..."
cd "$LOCAL_PATH"
npx vite build

# 2. Değişen dosyaları ve build edilmiş asset'leri sunucuya yükle
echo "📦 Dosyalar yükleniyor..."
rsync -avz --progress \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='tmp' \
  --exclude='log' \
  --exclude='storage' \
  --exclude='.bundle' \
  --exclude='public/packs' \
  -e "sshpass -p '$PASSWORD' ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no" \
  "$LOCAL_PATH/public/vite/" "$SERVER:$REMOTE_PATH/public/vite/"

# 3. docker-compose.production.yaml'ı da gönder (volume mount değişikliği için)
rsync -avz \
  -e "sshpass -p '$PASSWORD' ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no" \
  "$LOCAL_PATH/docker-compose.production.yaml" "$SERVER:$REMOTE_PATH/"

# 4. Container'ları restart et
echo "🔄 Container'lar restart ediliyor..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "$SERVER" << 'ENDSSH'
cd /root/cwais
docker compose -f docker-compose.production.yaml restart rails sidekiq
echo "⏳ Rails başlaması bekleniyor..."
sleep 10
echo "✅ Quick deploy tamamlandı!"
docker compose -f docker-compose.production.yaml ps
ENDSSH

echo ""
echo "✅ Quick Deploy tamamlandı!"
echo ""
