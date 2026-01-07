# Observability Runbook

## Request ID ile Log/Trace Bulma (10 Adım)

Bir hata olduğunda request_id ile log/trace bulma adımları:

### 1. Response'dan Request ID'yi Al
```bash
# HTTP response header'ından X-Request-Id değerini al
curl -i http://localhost:8080/ui/login | grep X-Request-Id
# Örnek: X-Request-Id: 123e4567-e89b-12d3-a456-426614174000
```

### 2. Laravel Log'larını Ara
```bash
# Pazar container içinde log dosyasını ara
docker compose exec pazar-app grep "123e4567-e89b-12d3-a456-426614174000" storage/logs/laravel.log
```

### 3. Structured Log Context'i Kontrol Et
Laravel log'larında structured context şu şekilde görünür:
```json
{
  "message": "...",
  "context": {
    "service": "pazar",
    "request_id": "123e4567-e89b-12d3-a456-426614174000",
    "route": "ui.login",
    "method": "POST",
    "tenant_id": 1,
    "user_id": 42,
    "world": "commerce"
  }
}
```

### 4. Request ID ile Tüm İlgili Log'ları Bul
```bash
# Tüm log dosyalarında request_id ile ara
docker compose exec pazar-app grep -r "123e4567-e89b-12d3-a456-426614174000" storage/logs/
```

### 5. H-OS Log'larını Kontrol Et (Remote Mode)
Eğer H-OS remote mode'da çalışıyorsa, aynı request_id H-OS log'larında da görünmeli:
```bash
# H-OS API log'larını kontrol et
docker compose logs hos-api | grep "123e4567-e89b-12d3-a456-426614174000"
```

### 6. HTTP Client Log'larını İncele
Pazar'dan H-OS'a giden HTTP çağrılarında X-Request-Id header'ı propagate edilir:
```bash
# Laravel HTTP client log'larında request_id'yi ara
docker compose exec pazar-app grep -A 5 "X-Request-Id.*123e4567" storage/logs/laravel.log
```

### 7. Outbox Event'lerini Kontrol Et
Contract transition event'lerinde request_id payload'da saklanır:
```bash
# Database'de outbox event'lerini kontrol et
docker compose exec pazar-app php artisan tinker
# DB::table('hos_outbox_events')->whereJsonContains('payload', ['request_id' => '123e4567-e89b-12d3-a456-426614174000'])->get();
```

### 8. Correlation ID ile Trace Oluştur
Request ID tüm ilgili log/trace'leri birleştirir:
```
Request: POST /ui/login
├─ Pazar Log: [request_id: 123e4567] Controller entry
├─ Pazar Log: [request_id: 123e4567] HOS call started
├─ H-OS Log:  [request_id: 123e4567] Policy check
├─ H-OS Log:  [request_id: 123e4567] Contract validation
└─ Pazar Log: [request_id: 123e4567] Response sent
```

### 9. Hata Durumunda Full Trace
Eğer bir hata varsa, request_id ile tüm trace'i topla:
```bash
# Tüm servislerden request_id ile log topla
docker compose logs --since 1h | grep "123e4567-e89b-12d3-a456-426614174000" > /tmp/trace.log
cat /tmp/trace.log
```

### 10. Debug için Request ID Set Et
Manual test için X-Request-Id header'ı set et:
```bash
# Custom request_id ile test
curl -H "X-Request-Id: test-debug-001" -i http://localhost:8080/up
# Response'da aynı request_id dönmeli
```

## Notlar

- **Request ID Format**: UUID v4 (36 karakter)
- **Propagation**: Pazar → H-OS (HTTP header: X-Request-Id)
- **Storage**: Laravel log context, outbox event payload (optional)
- **Correlation**: Aynı request_id tüm ilgili log/trace'leri birleştirir

