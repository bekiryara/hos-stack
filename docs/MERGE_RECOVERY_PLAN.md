# Merge Recovery Plan - Önemli Dosyaları Geri Getirme

**Tarih:** 2026-01-22  
**Amaç:** Merge öncesi ve sonrası karşılaştırma yaparak önemli dosyaları geri getirme planı

---

## 📋 Plan Özeti

1. **Merge Öncesi ve Sonrası Karşılaştırma**
   - Merge commit'ini tespit et
   - Merge öncesi dosya listesi
   - Merge sonrası dosya listesi
   - Kaybolan/Değişen dosyaları tespit et

2. **Önemli Dosyaları Kategorize Et**
   - Kritik dosyalar (SPEC.md, WP_CLOSEOUTS.md, vb.)
   - Ops scriptleri
   - Proof dosyaları
   - Route dosyaları
   - Frontend dosyaları

3. **Geri Getirme Stratejisi**
   - Her dosya için kaynak commit belirle
   - Güvenli geri getirme yöntemi
   - Test ve doğrulama

---

## 🔍 AŞAMA 1: Merge Analizi

### 1.1. Merge Commit'ini Tespit Et

**Hedef:** Hangi commit merge yapıldı?

**Adımlar:**
- `git log --oneline --merges` ile merge commit'lerini bul
- En son merge commit'ini tespit et (muhtemelen `e837a4f`)
- Merge commit'inin detaylarını incele

**Beklenen Çıktı:**
- Merge commit hash'i
- Merge tarihi
- Merge edilen branch'ler

### 1.2. Merge Öncesi Dosya Listesi

**Hedef:** Merge öncesi hangi dosyalar vardı?

**Adımlar:**
- Merge commit'inden önceki commit'i al (`e837a4f^`)
- `git ls-tree -r --name-only e837a4f^` ile dosya listesi
- Önemli klasörleri filtrele:
  - `docs/`
  - `ops/`
  - `work/pazar/routes/api/`
  - `work/marketplace-web/`

**Beklenen Çıktı:**
- Merge öncesi toplam dosya sayısı
- Klasör bazında dosya listesi

### 1.3. Merge Sonrası Dosya Listesi

**Hedef:** Merge sonrası hangi dosyalar var?

**Adımlar:**
- Merge commit'inden sonraki commit'i al (`e837a4f`)
- `git ls-tree -r --name-only e837a4f` ile dosya listesi
- Aynı klasörleri filtrele

**Beklenen Çıktı:**
- Merge sonrası toplam dosya sayısı
- Klasör bazında dosya listesi

### 1.4. Kaybolan/Değişen Dosyaları Tespit Et

**Hedef:** Hangi dosyalar kayboldu veya değişti?

**Adımlar:**
- İki listeyi karşılaştır
- Kaybolan dosyaları tespit et
- Değişen dosyaları tespit et (`git diff e837a4f^..e837a4f`)

**Beklenen Çıktı:**
- Kaybolan dosya listesi
- Değişen dosya listesi
- Her dosya için değişiklik miktarı

---

## 📁 AŞAMA 2: Önemli Dosyaları Kategorize Et

### 2.1. Kritik Dosyalar

**Kategori:** Mutlaka geri getirilmesi gereken dosyalar

**Dosyalar:**
- `docs/SPEC.md` - Canonical specification
- `docs/WP_CLOSEOUTS.md` - Workspace Package summaries
- `docs/SPEC.md` - Specification
- `docs/CURRENT.md` - Current system state
- `docs/DECISIONS.md` - Baseline decisions
- `docs/ONBOARDING.md` - Quick start guide

**Kontrol:**
- Her dosya için merge öncesi versiyonu var mı?
- Merge sonrası içerik kaybı var mı?

### 2.2. Ops Scriptleri

**Kategori:** Operasyonel scriptler

**Dosyalar:**
- `ops/*.ps1` - Tüm PowerShell scriptleri
- Özellikle:
  - `ops/pazar_spine_check.ps1`
  - `ops/world_status_check.ps1`
  - `ops/catalog_contract_check.ps1`
  - `ops/listing_contract_check.ps1`
  - `ops/reservation_contract_check.ps1`

**Kontrol:**
- Hangi scriptler kayboldu?
- Hangi scriptler değişti?
- WP_CLOSEOUTS.md'de bahsedilen scriptler mevcut mu?

### 2.3. Proof Dosyaları

**Kategori:** Kanıt dokümantasyonu

**Dosyalar:**
- `docs/PROOFS/*.md` - Tüm proof dosyaları

**Kontrol:**
- WP_CLOSEOUTS.md'de bahsedilen proof dosyaları mevcut mu?
- Hangi proof dosyaları kayboldu?

### 2.4. Route Dosyaları

**Kategori:** API route dosyaları

**Dosyalar:**
- `work/pazar/routes/api/*.php` - Route modülleri
- Özellikle:
  - `00_ping.php`
  - `00_metrics.php`
  - `01_world_status.php`
  - `02_catalog.php`
  - `03a_listings_write.php`
  - `03b_listings_read.php`
  - `03c_offers.php`
  - `04_reservations.php`
  - `05_orders.php`
  - `06_rentals.php`
  - `account_portal.php`
  - `messaging.php`

**Kontrol:**
- Tüm route dosyaları mevcut mu?
- Route dosyaları değişti mi?

### 2.5. Frontend Dosyaları

**Kategori:** Frontend kaynak dosyaları

**Dosyalar:**
- `work/marketplace-web/src/**` - Frontend kaynak dosyaları
- Özellikle:
  - `src/api/client.js`
  - `src/pages/AccountPortalPage.vue`
  - `vite.config.js`

**Kontrol:**
- Frontend dosyaları mevcut mu?
- Frontend dosyaları değişti mi?

---

## 🔄 AŞAMA 3: Geri Getirme Stratejisi

### 3.1. Her Dosya İçin Kaynak Commit Belirle

**Hedef:** Her dosya için hangi commit'ten geri getirilecek?

**Yöntem:**
- Merge öncesi commit'te dosya var mı kontrol et
- Varsa: `e837a4f^` (merge öncesi)
- Yoksa: Daha eski commit'lerde ara
- `git log --all --full-history -- <dosya-yolu>` ile geçmişi bul

**Öncelik Sırası:**
1. Merge öncesi commit (`e837a4f^`)
2. Restore commit'i (`3936c28`) - WP_CLOSEOUTS.md için
3. Daha eski commit'ler

### 3.2. Güvenli Geri Getirme Yöntemi

**Hedef:** Dosyaları güvenli şekilde geri getir

**Yöntem 1: Tek Dosya Geri Getirme**
```bash
# Dosyayı belirli bir commit'ten geri getir
git checkout <commit-hash> -- <dosya-yolu>
```

**Yöntem 2: Klasör Geri Getirme**
```bash
# Tüm klasörü geri getir
git checkout <commit-hash> -- <klasor-yolu>/
```

**Yöntem 3: Toplu Geri Getirme**
```bash
# Birden fazla dosyayı geri getir
git checkout <commit-hash> -- <dosya1> <dosya2> <dosya3>
```

**Güvenlik Kontrolleri:**
- Geri getirmeden önce mevcut dosyayı yedekle
- Geri getirdikten sonra diff kontrol et
- Test et ve doğrula

### 3.3. Test ve Doğrulama

**Hedef:** Geri getirilen dosyaların doğruluğunu kontrol et

**Kontroller:**
1. **Dosya Varlığı:**
   - Dosya gerçekten geri geldi mi?
   - Dosya boyutu doğru mu?

2. **İçerik Kontrolü:**
   - İçerik merge öncesi ile aynı mı?
   - Önemli bölümler eksik mi?

3. **Bağımlılık Kontrolü:**
   - Diğer dosyalar bu dosyaya bağımlı mı?
   - Bağımlılıklar çalışıyor mu?

4. **Test Çalıştırma:**
   - İlgili test scriptlerini çalıştır
   - Hata var mı kontrol et

---

## 📝 AŞAMA 4: Uygulama Adımları

### 4.1. Hazırlık

**Adımlar:**
1. Mevcut durumu yedekle
   - `git status` ile değişiklikleri kontrol et
   - Değişiklikler varsa commit et veya stash et
2. Yeni branch oluştur
   - `git checkout -b merge-recovery-20260122`
3. Çalışma dizinini temizle
   - `git clean -fd` (dikkatli kullan)

### 4.2. Analiz Çalıştırma

**Adımlar:**
1. AŞAMA 1'i uygula (Merge Analizi)
2. Sonuçları kaydet
3. Kaybolan dosya listesini oluştur

### 4.3. Kategorize Etme

**Adımlar:**
1. AŞAMA 2'yi uygula (Kategorize Etme)
2. Her kategori için dosya listesi oluştur
3. Öncelik sırası belirle

### 4.4. Geri Getirme

**Adımlar:**
1. Her kategori için sırayla:
   - Kaynak commit'i belirle
   - Dosyaları geri getir
   - Test et ve doğrula
   - Commit et
2. Tüm kategoriler tamamlandığında:
   - Final test çalıştır
   - Sonuçları dokümante et

### 4.5. Doğrulama

**Adımlar:**
1. Tüm dosyalar geri geldi mi kontrol et
2. Test scriptlerini çalıştır:
   - `ops/verify_wp_closeouts.ps1`
   - `ops/pazar_spine_check.ps1`
3. Sonuçları raporla

---

## ⚠️ DİKKAT EDİLMESİ GEREKENLER

1. **Yedekleme:**
   - Her adımdan önce mevcut durumu yedekle
   - Önemli değişiklikleri commit et

2. **Test:**
   - Her dosya geri getirildikten sonra test et
   - Tüm dosyalar geri getirildikten sonra genel test çalıştır

3. **Dokümantasyon:**
   - Her adımı dokümante et
   - Hangi dosyalar geri getirildi kaydet
   - Hangi dosyalar geri getirilemedi kaydet

4. **Güvenlik:**
   - Production'a push etmeden önce test et
   - Geri getirilen dosyaları review et

---

## 📊 Beklenen Sonuçlar

### Başarı Kriterleri:
- ✅ Tüm kritik dosyalar geri getirildi
- ✅ Tüm ops scriptleri mevcut
- ✅ Tüm route dosyaları mevcut
- ✅ Tüm proof dosyaları mevcut (veya eksikler dokümante edildi)
- ✅ Test scriptleri PASS
- ✅ WP_CLOSEOUTS.md doğru (46 WP mevcut)

### Rapor:
- Geri getirilen dosya sayısı
- Geri getirilemeyen dosya sayısı
- Test sonuçları
- Öneriler

---

## 🔗 İlgili Dosyalar

- `docs/WP_CLOSEOUTS.md` - Workspace Package summaries
- `docs/SPEC.md` - Canonical specification
- `ops/verify_wp_closeouts.ps1` - WP closeouts verification
- `ops/pazar_spine_check.ps1` - Pazar spine check

---

## 📅 Uygulama Takvimi

1. **AŞAMA 1 (Analiz):** 30 dakika
2. **AŞAMA 2 (Kategorize):** 20 dakika
3. **AŞAMA 3 (Strateji):** 30 dakika
4. **AŞAMA 4 (Uygulama):** 1-2 saat
5. **Doğrulama:** 30 dakika

**Toplam Tahmini Süre:** 3-4 saat

---

**Not:** Bu plan sadece bir rehberdir. Gerçek duruma göre adımlar ayarlanabilir.


