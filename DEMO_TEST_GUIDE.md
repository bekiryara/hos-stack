# Demo Test Guide - Kısa Özet

## 1. Stack'i Başlat
```powershell
.\ops\stack_up.ps1
# veya
docker compose up -d
```

## 2. Tarayıcıda Test Et

### A) Kullanıcı Kayıt/Giriş
1. `http://localhost:3002/marketplace/register` → Yeni kullanıcı kaydet
2. `http://localhost:3002/marketplace/login` → Giriş yap

### B) Listing Browse
1. Ana sayfa: `http://localhost:3002/marketplace/` → Kategoriler görünmeli
2. Bir kategoriye tıkla → Listings görünmeli
3. Bir listing'e tıkla → Detay sayfası açılmalı

### C) Reservation/Rental/Order Oluştur
1. Listing detayında "Reserve" veya "Rent" veya "Buy" butonuna tıkla
2. Formu doldur, gönder
3. Başarı mesajı görünmeli

### D) "Hesabım" Sayfası
1. `http://localhost:3002/marketplace/account` → Hesabım sayfası
2. "Rezervasyonlarım", "Kiralamalarım", "Siparişlerim" listelerinde yeni oluşturduğun görünmeli

### E) Firm/Tenant Oluştur (Opsiyonel)
1. Hesabım sayfasında firm oluştur
2. `http://localhost:3002/marketplace/listing/create` → Yeni listing oluştur
3. Listing'i publish et

## 3. Hızlı Ops Test (Opsiyonel)
```powershell
.\ops\verify.ps1                    # Stack sağlık kontrolü
.\ops\catalog_contract_check.ps1    # Kategori testi
.\ops\listing_contract_check.ps1    # Listing testi
```

## 4. Sorun Görürsen
```powershell
docker compose logs pazar-app       # Pazar logları
docker compose logs hos-api         # HOS logları
docker compose logs hos-web         # Frontend logları
```

## ✅ Başarı Kriterleri
- ✅ Register/Login çalışıyor
- ✅ Listings görüntüleniyor
- ✅ Reservation/Rental/Order oluşturulabiliyor
- ✅ "Hesabım" sayfasında görünüyor
- ✅ Hata mesajı yok (401, 500, vb.)

---

**Not**: Frontend değişikliği yaptıysan:
```powershell
docker compose build hos-web
docker compose up -d --force-recreate hos-web
```

