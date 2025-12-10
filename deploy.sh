#!/bin/bash
# CWAIS Deploy Script
# Kullanım: ./deploy.sh [--init]
#   --init: İlk kurulum için (deploy scriptini sunucuya kopyalar)

set -e

SERVER="root@167.71.72.107"
PASSWORD="74a5cf511f2Ecdf70e"
REMOTE_PATH="/root/cwais"
LOCAL_PATH="/Users/harun/Desktop/PROJECTS/cwais"

echo "🚀 Deploy başlıyor..."

# 1. Dosyaları sunucuya yükle
echo "📦 Dosyalar yükleniyor..."
rsync -avz --progress \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='tmp' \
  --exclude='log' \
  --exclude='storage' \
  --exclude='.bundle' \
  --exclude='public/packs' \
  --exclude='public/vite' \
  -e "sshpass -p '$PASSWORD' ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no" \
  "$LOCAL_PATH/" "$SERVER:$REMOTE_PATH/"

# 2. İlk kurulumda veya --init flag'i varsa remote deploy scriptini kopyala
if [ "$1" == "--init" ]; then
  echo "📝 Sunucu deploy scripti kuruluyor..."
  sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "$SERVER" \
    "cp $REMOTE_PATH/docker/scripts/remote-deploy.sh /root/deploy.sh && chmod +x /root/deploy.sh"
fi

# 3. Sunucuda deploy script'ini çalıştır
echo "🔨 Build başlatılıyor (arka planda)..."
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no "$SERVER" \
  "nohup /root/deploy.sh > /tmp/deploy.log 2>&1 &"

echo ""
echo "✅ Dosyalar yüklendi ve build başladı!"
echo ""
echo "📋 Build durumunu takip etmek için:"
echo "   sshpass -p '$PASSWORD' ssh $SERVER 'tail -f /tmp/deploy.log'"
echo ""
echo "⏱️  Build genellikle 3-5 dakika sürer."
echo ""
echo "🔧 İlk kurulum için: ./deploy.sh --init"
