# ESKİ/YENİ SİSTEM TEMİZLİK ÖZETİ

**Tarih:** 2026-01-18

## YAPILAN DEĞİŞİKLİKLER

### ✅ Güncellenen Dokümantasyon/Config Dosyaları (Güvenli)

1. **docs/PRODUCT/PRODUCT_ROADMAP.md**
   - commerce/food/rentals → marketplace dünya
   - services/real_estate/vehicle → kaldırıldı
   - messaging/social → disabled worlds

2. **docs/PRODUCT/PRODUCT_API_SPINE.md**
   - Enabled worlds: marketplace (commerce/food/rentals vertical'ları)
   - Disabled: messaging, social

3. **docs/PRODUCT/MVP_SCOPE.md**
   - World 1 (Commerce) → marketplace (commerce vertical)
   - commerce/food/rentals → vertical'lar

4. **docs/runbooks/product_spine.md**
   - commerce/food/rentals dünya referansları silindi
   - Sadece marketplace dünyası yazıldı

5. **docs/RULES.md**
   - All enabled worlds (commerce, food, rentals) → marketplace world

6. **docs/RELEASES/RC0.md**
   - World 1: commerce → marketplace world

7. **work/pazar/config/worlds.php**
   - enabled: ['marketplace']
   - disabled: ['messaging', 'social']

8. **work/pazar/WORLD_REGISTRY.md**
   - Enabled: marketplace
   - Disabled: messaging, social
   - commerce/food/rentals → vertical'lar olarak belirtildi

### ⏸️ Dokunulmayan Kod Dosyaları (Hata Riski)

- Route dosyaları (`routes/api/*.php`)
- `WorldRegistry.php` (defaultKey() hala 'commerce')
- `Listing.php` (WORLDS const hala commerce/food/rentals)

## ŞU ANKİ DÜNYALAR

- core (ONLINE)
- marketplace (ONLINE)
- messaging (DISABLED)
- social (DISABLED)

Commerce/food/rentals artık dünya değil, marketplace'in vertical'ları.

---

## KAOSTAN KURTULMA PLANI

### AŞAMA 1: GİTHUB TEMİZLİK (Öncelikli)

**Sorun:** Git status'ta çok fazla değişiklik var, çöplük gibi görünüyor.

**Yapılacaklar:**
1. ✅ **Dokümantasyon değişikliklerini commit et**
   - MD dosyaları (PRODUCT_ROADMAP.md, PRODUCT_API_SPINE.md, MVP_SCOPE.md, product_spine.md, RULES.md, RC0.md)
   - WORLD_REGISTRY.md
   - Config: worlds.php

2. ⏸️ **node_modules değişikliklerini ignore et**
   - `.gitignore` kontrol et
   - node_modules zaten ignore edilmeli

3. ⏸️ **docs/ANALYSIS/ klasörünü temizle**
   - Sadece `eski_yeni_sistem_temizlik_ozeti.md` kalsın
   - Diğer analiz dosyaları zaten silindi

4. ⏸️ **Silinen dosyaları commit et**
   - `work/hos/docs/pazar/WORLD_REGISTRY.md` (duplicate, silindi)
   - `work/hos_backup_20260120_231900` (backup, silindi)

### AŞAMA 2: KOD DOSYALARI (Hata Riski - Dikkatli)

**Kural:** Route dosyalarına dokunmayacağız (kullanıcı istemedi).

**Yapılacaklar:**
1. ⏸️ **WorldRegistry.php defaultKey() düzelt** (OPSİYONEL - düşük risk)
   - Şu an: `return !empty($enabled) ? (string) reset($enabled) : 'commerce';`
   - Olmalı: `return !empty($enabled) ? (string) reset($enabled) : 'marketplace';`
   - **Risk:** Düşük (sadece fallback değer, enabled array'den okuyor zaten)
   - **Not:** Şu an çalışıyor (enabled array'de marketplace var)

2. ⏸️ **Route dosyalarına DOKUNMAYACAĞIZ**
   - 01_world_status.php → DOKUNMAYACAĞIZ
   - Diğer route dosyaları → DOKUNMAYACAĞIZ
   - **Sebep:** Kullanıcı istemedi, hata riski

3. ⏸️ **Listing.php WORLDS const** (OPSİYONEL - yüksek risk)
   - Şu an: `public const WORLDS = ['commerce', 'food', 'rentals'];`
   - Olmalı: Kaldırılabilir veya `['marketplace']`
   - **Risk:** Yüksek (model dosyası, kullanım yerleri kontrol edilmeli)
   - **Not:** Kullanıcı "Listing.php'ye neden dokundun" dedi, dokunmayacağız

### AŞAMA 3: TEST VE DOĞRULAMA

**Yapılacaklar:**
1. ⏸️ **Config değişikliklerini test et**
   - `config/worlds.php` → enabled: marketplace
   - WorldRegistry çalışıyor mu?

2. ⏸️ **Route dosyalarını test et**
   - `/api/world/status` → marketplace döndürüyor mu?
   - Hata var mı?

3. ⏸️ **Dokümantasyon tutarlılığı**
   - Tüm MD dosyaları marketplace yazıyor mu?
   - Commerce/food/rentals dünya olarak geçiyor mu?

### AŞAMA 4: COMMIT STRATEJİSİ

**Yapılacaklar:**
1. ⏸️ **Ayrı commit'ler**
   - Commit 1: Dokümantasyon güncellemeleri
   - Commit 2: Config güncellemeleri
   - Commit 3: Kod düzeltmeleri (eğer yapılırsa)

2. ⏸️ **Commit mesajları**
   - "docs: Update world references from commerce/food/rentals to marketplace"
   - "config: Update worlds.php to use marketplace world"
   - "fix: Update WorldRegistry defaultKey to marketplace"

### ÖNCELİK SIRASI

1. **ŞİMDİ:** GitHub temizlik (commit dokümantasyon ve config)
2. **SONRA:** WorldRegistry.php defaultKey() düzelt (opsiyonel, düşük risk)
3. **DOKUNMAYACAĞIZ:** Route dosyaları (01_world_status.php, vs.)
4. **DOKUNMAYACAĞIZ:** Listing.php (WORLDS const)

### KURALLAR

- ❌ Route dosyalarına dokunmayacağız (kullanıcı istemedi, hata riski)
- ❌ Listing.php'ye dokunmayacağız (kullanıcı istemedi)
- ✅ Yeni MD dosyası açmayacağız (sadece mevcut özet)
- ✅ Sadece dokümantasyon ve config güncellenecek
- ⏸️ Kod dosyaları opsiyonel (WorldRegistry.php defaultKey() sadece)

