# Shopify Database Kurulum Rehberi

## 1. Supabase'de pgvector Extension'ı Etkinleştir

Supabase SQL Editor'da şu komutu çalıştır:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

## 2. Migration'ları Çalıştır

### Production'da:

```bash
# Docker container içinde
docker-compose exec rails RAILS_ENV=production bundle exec rake shopify_db:migrate

# Veya direkt production sunucusunda
RAILS_ENV=production bundle exec rake shopify_db:migrate
```

### Development'ta (local test için):

Eğer local'de test etmek istiyorsan, Supabase connection bilgilerini kullanabilirsin veya local bir PostgreSQL kurup test edebilirsin.

## 3. Connection Test

```bash
# Production'da
RAILS_ENV=production bundle exec rake shopify_db:test_connection
```

## 4. İlk Sync'i Başlat

Rails console'dan:

```ruby
account = Account.find(ACCOUNT_ID)
hook = account.hooks.find_by(app_id: 'shopify')
Shopify::SyncProductsMasterJob.perform_later(account.id, hook.id)
```

Veya API'den:

```bash
POST /api/v1/accounts/:account_id/integrations/shopify/sync_products
```

## 5. Sync Durumunu Kontrol Et

```bash
GET /api/v1/accounts/:account_id/integrations/shopify/sync_status
```

## Notlar

- Supabase connection bilgileri `config/database.yml` içinde tanımlı
- Development'ta Docker container'dan Supabase'e erişim için network ayarları gerekebilir
- Production'da direkt erişim olacak
- pgvector extension mutlaka etkinleştirilmeli (vector search için)

