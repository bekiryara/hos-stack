# WP-4.4 DIFF PLAN (En Kısa)

## Mevcut Durum

### gate-pazar-spine.yml
```yaml
- name: Seed required data
  run: |
    docker compose exec -T pazar-app php artisan db:seed --class=CatalogSpineSeeder --force || true
```

**Problem:** `|| true` seeder hatasını gizliyor, CI gate her zaman yeşil görünüyor.

### CatalogSpineSeeder.php
**Problem:** `insertGetId()` kullanıyor → duplicate key violation (idempotent değil)

## Değişiklikler

### 1. CatalogSpineSeeder.php
- `insertGetId()` → `updateOrInsert(['slug' => '...'])` (tüm kategoriler için)
- `insertOrIgnore()` → `updateOrInsert(['category_id' => ..., 'attribute_key' => ...])` (filter schema için)

**Etki:** Seeder idempotent, çoklu çalıştırma güvenli.

### 2. gate-pazar-spine.yml
- `|| true` kaldır
- `continue-on-error: false` ekle

**Etki:** Seeder hatası CI job'ı durdurur.

## Dosyalar
1. `work/pazar/database/seeders/CatalogSpineSeeder.php` (MODIFIED)
2. `.github/workflows/gate-pazar-spine.yml` (MODIFIED)

## Test
```powershell
# Seeder 2x çalıştır (idempotent olmalı)
docker compose exec -T pazar-app php artisan db:seed --class=CatalogSpineSeeder --force
docker compose exec -T pazar-app php artisan db:seed --class=CatalogSpineSeeder --force

# Catalog check PASS olmalı
.\ops\catalog_contract_check.ps1
```



