#!/bin/bash

# Production'da Shopify migration'larını çalıştır
# Kullanım: ./RUN_PRODUCTION_MIGRATIONS.sh

echo "🚀 Shopify Database Migration'larını çalıştırıyorum..."

# 1. Connection test
echo ""
echo "📡 Connection test ediliyor..."
RAILS_ENV=production bundle exec rake shopify_db:test_connection

if [ $? -ne 0 ]; then
    echo "❌ Connection başarısız! Supabase erişimini kontrol edin."
    exit 1
fi

echo "✅ Connection başarılı!"
echo ""

# 2. Migration'ları çalıştır
echo "📦 Migration'lar çalıştırılıyor..."
RAILS_ENV=production bundle exec rake shopify_db:migrate

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration'lar başarıyla tamamlandı!"
    echo ""
    echo "Sonraki adımlar:"
    echo "1. Supabase SQL Editor'da: CREATE EXTENSION IF NOT EXISTS vector;"
    echo "2. İlk sync'i başlat: POST /api/v1/accounts/:account_id/integrations/shopify/sync_products"
else
    echo ""
    echo "❌ Migration hatası oluştu!"
    exit 1
fi

