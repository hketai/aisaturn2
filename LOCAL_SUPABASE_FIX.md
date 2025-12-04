# Local Supabase Connection Sorunu Çözümü

## Sorun
Docker container'dan Supabase'e erişim timeout alıyor. Bu Supabase'in firewall ayarlarından kaynaklanıyor.

## Çözüm 1: Supabase Dashboard'da IP Whitelist (Önerilen)

1. Supabase Dashboard'a git: https://supabase.com/dashboard
2. Projeni seç
3. Settings → Database → Connection Pooling
4. "Allowed IP addresses" bölümüne Docker container'ın IP'sini ekle
5. Veya "Allow all IPs" seçeneğini aktif et (development için güvenli)

## Çözüm 2: Connection String Kullan

Supabase Dashboard'dan connection string'i al ve direkt kullan:

```yaml
# config/database.yml
shopify:
  url: <%= ENV.fetch('SHOPIFY_DB_URL', 'postgresql://postgres:PASSWORD@db.hkoawgewdmqgadwuxozv.supabase.co:5432/postgres?sslmode=require') %>
```

## Çözüm 3: Local PostgreSQL ile Test (Geçici)

Development'ta test için local PostgreSQL kullan:

```bash
# Local'de PostgreSQL container başlat
docker run -d \
  --name shopify-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=shopify_dev \
  -p 5433:5432 \
  pgvector/pgvector:pg16

# Extension'ı etkinleştir
docker exec -it shopify-postgres psql -U postgres -d shopify_dev -c "CREATE EXTENSION vector;"
```

Sonra `.env` dosyasına ekle:
```bash
SHOPIFY_DB_HOST=localhost
SHOPIFY_DB_PORT=5433
SHOPIFY_DB_DATABASE=shopify_dev
SHOPIFY_DB_USERNAME=postgres
SHOPIFY_DB_PASSWORD=postgres
```

## Çözüm 4: Production'da Test

Local'de test yapmak yerine, production sunucusunda direkt test edebilirsin. Production'da network sorunu olmayacak.

## Hızlı Test Komutu

```bash
# Connection pooler ile (port 6543)
SHOPIFY_DB_PORT=6543 docker-compose exec rails bundle exec rake shopify_db:test_connection

# Direct connection ile (port 5432)
SHOPIFY_DB_PORT=5432 docker-compose exec rails bundle exec rake shopify_db:test_connection
```

