# Supabase Connection Sorun Giderme

## Sorun: Docker container'dan Supabase'e erişim timeout

### Çözüm 1: Supabase Connection Pooler Kullan

Supabase'de iki farklı port var:
- **Direct connection**: `5432` (IPv6 gerekli, firewall strict)
- **Connection pooler**: `6543` (IPv4 destekli, daha esnek)

Connection pooler'ı kullanmak için `config/database.yml`'de port'u değiştir:

```yaml
shopify:
  port: 6543  # Connection pooler port
```

### Çözüm 2: Supabase Dashboard'da IP Whitelist

1. Supabase Dashboard → Settings → Database
2. "Connection Pooling" bölümüne git
3. IP whitelist'e Docker container'ın IP'sini ekle
4. Veya "Allow all IPs" seçeneğini aktif et (development için)

### Çözüm 3: Connection String Kullan

Supabase'den alınan connection string'i direkt kullan:

```yaml
shopify:
  url: <%= ENV.fetch('SHOPIFY_DB_URL', 'postgresql://postgres:74a5cf511f2Ecdf70e@db.hkoawgewdmqgadwuxozv.supabase.co:5432/postgres?sslmode=require') %>
```

### Çözüm 4: Local Test için Mock Database

Development'ta test için local PostgreSQL kullan:

```yaml
development:
  shopify:
    <<: *default
    host: localhost
    port: 5433  # Farklı port
    database: "shopify_dev"
    username: "postgres"
    password: "postgres"
```

Sonra local'de:
```bash
createdb shopify_dev
psql shopify_dev -c "CREATE EXTENSION vector;"
```

## Hızlı Test

```bash
# Connection pooler ile test
SHOPIFY_DB_PORT=6543 docker-compose exec rails bundle exec rake shopify_db:test_connection

# Direct connection ile test
SHOPIFY_DB_PORT=5432 docker-compose exec rails bundle exec rake shopify_db:test_connection
```

