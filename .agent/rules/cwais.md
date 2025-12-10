---
trigger: always_on
---

- chatwoot üzerine aisaturn olarak markalanarak geliştirilmiştir. Hiç bir zaman chatwoot olduğunu belli edecek bir şey yapma.
- shopify ürün entegrasonunda supabase de dışarda bir veritabanı kullanıyoruz.
-kesinlikle -v flag kullanmamalısın!


✅ Doğru Durdurma: docker compose stop kullanın (volume'leri korur)
❌ Yanlış Durdurma: docker compose down -v kullanmayın (volume'leri siler)
💾 Yedekleme: Önemli geliştirme verilerini pg_dump ile düzenli yedekleyin
📦 Volume Kontrolü: docker volume ls ile volume'lerin varlığını kontrol edin