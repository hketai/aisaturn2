# CWAIS Production Deployment Guide

## Gereksinimler

- Docker 24.0+
- Docker Compose 2.0+
- 8GB+ RAM (önerilen 16GB+)
- 50GB+ disk alanı

## Hızlı Kurulum

### 1. Projeyi sunucuya kopyala

```bash
# Lokal makineden
rsync -avz --exclude='.git' --exclude='node_modules' --exclude='tmp' \
  /path/to/cwais/ user@server:/root/cwais/
```

### 2. .env dosyasını oluştur

```bash
cd /root/cwais

# Örnek .env dosyasını kopyala
cp .env.example .env

# Değişkenleri düzenle
nano .env
```

**Kritik .env değişkenleri:**

```bash
# Database
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DATABASE=chatwoot
POSTGRES_USERNAME=postgres
POSTGRES_PASSWORD=<güçlü-şifre>

# Redis
REDIS_PASSWORD=<güçlü-şifre>

# Rails
SECRET_KEY_BASE=<rails-secret-key>
RAILS_ENV=production
FRONTEND_URL=https://your-domain.com

# Storage (S3 veya local)
ACTIVE_STORAGE_SERVICE=local
```

### 3. Kurulum scriptini çalıştır

```bash
chmod +x docker/scripts/setup-production.sh
bash docker/scripts/setup-production.sh
```

## Manuel Kurulum

### 1. Docker imajlarını build et

```bash
docker compose -f docker-compose.production.yaml build --no-cache
```

### 2. Servisleri başlat

```bash
# Önce database ve redis
docker compose -f docker-compose.production.yaml up -d postgres redis

# Postgres hazır olana kadar bekle
sleep 10

# Rails ve Sidekiq
docker compose -f docker-compose.production.yaml up -d rails sidekiq whatsapp-web
```

### 3. Database migration

```bash
docker compose -f docker-compose.production.yaml exec rails bundle exec rails db:prepare
```

## Güncelleme

```bash
# Dosyaları güncelle (rsync veya git pull)
git pull origin main

# Update scriptini çalıştır
bash docker/scripts/update-production.sh
```

## Yararlı Komutlar

```bash
# Logları görüntüle
docker compose -f docker-compose.production.yaml logs -f rails

# Container durumlarını kontrol et
docker compose -f docker-compose.production.yaml ps

# Rails console
docker compose -f docker-compose.production.yaml exec rails bundle exec rails c

# Servisleri yeniden başlat
docker compose -f docker-compose.production.yaml restart rails sidekiq

# Tüm servisleri durdur
docker compose -f docker-compose.production.yaml down

# Volumeler dahil tamamen temizle (DİKKAT: Tüm veriler silinir!)
docker compose -f docker-compose.production.yaml down -v
```

## Nginx Yapılandırması

Sunucunun önünde Nginx reverse proxy kullanılması önerilir:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
```

## Sorun Giderme

### Bundle install sonsuz döngüde kalıyor

```bash
# Container'ı durdur ve gem cache'ini temizle
docker compose -f docker-compose.production.yaml down rails sidekiq
docker volume rm cwais_bundle_data
docker compose -f docker-compose.production.yaml up -d rails sidekiq
```

### "Git hardlink" hatası

Bu hata Docker overlay filesystem'de git clone yaparken oluşur. `docker/entrypoints/rails.sh` dosyasında `git config --global core.hardlinks false` zaten ayarlanmış olmalı.

### Database bağlantı hatası

```bash
# Postgres çalışıyor mu kontrol et
docker compose -f docker-compose.production.yaml ps postgres

# Postgres loglarını kontrol et
docker compose -f docker-compose.production.yaml logs postgres
```

### Memory sorunu (OOM Killer)

```bash
# Container memory kullanımını kontrol et
docker stats

# Swap ekle (eğer yoksa)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

