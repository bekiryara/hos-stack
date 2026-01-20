# KANONİK MODEL — Akış (Satış/Rezervasyon) + Üst Sınıf + Kategori (TR)

Amaç: Pazar “satış / kiralama / hizmet / yemek / otel” gibi dünyaları büyütürken **şişmeden** ilerlemek ve “ileride patlama” riskini düşürmek.

Bu sayfa **karar kilidi**dir: Yeni özellikler bu çerçeveye uymalıdır.

## 1) 3 kavram (karıştırma)

### 1.1 Akış (Flow) = iş akışı / butonlar / operasyon
- **Satış** (`sale`) → `Order` akışı  
  Örn: ürün satışı, yemek siparişi, tek seferlik paket satışı (tarih yok).
- **Rezervasyon** (`booking`) → `Reservation` akışı  
  Örn: otel, araç, gayrimenkul, randevulu hizmet, ekipman/iPhone kiralama (tarih/slot var).

**Kural**:  
- **Tarih/slot seçiliyorsa → Rezervasyon akışı**  
- **Tarih yoksa → Satış akışı**

> Bu kural, UI’daki butonların adlarını ve allowed geçişleri netleştirir.

Terminoloji notu (sapma önleyici):
- Dokümanlarda “Rezervasyon akışı” dendiğinde kastedilen **`Reservation` modeli + takvimli operasyon**dur.
- “booking” sadece teknik etiket/alias; ekip içi konuşmada “rezervasyon” kullanmak daha nettir.

### 1.2 Üst Sınıf = form alanları / ilan türü (az ve sabit)
Üst sınıf “form şemasını” belirler: Araç formu ≠ Gayrimenkul formu.

Önerilen üst sınıflar (TR):
- **Ürün**
- **Araç**
- **Gayrimenkul**
- **Konaklama**
- **Hizmet**
- **Yemek**

> Üst sınıf sayısı az tutulur (6–7). Böylece form şişmez.

### 1.3 Kategori = vitrin/SEO/filtre (kurala karışmaz)
Kategori sadece “vitrinde nerede görünsün?” sorusuna cevap verir.

- Ürün kategorisi: Elektronik → Telefon → iPhone
- Araç kategorisi: SUV / Sedan / Motosiklet
- Yemek kategorisi: Kebap / Pide / İçecek
- Hizmet kategorisi: Organizasyon / Temizlik / Bakım

**Kural**: Kategori **akışı ve formu belirlemez** (aksi patlatır).

## 2) Neden bu model “patlamaz”?
- Akış sayısı **2** (sale/booking) → operasyon/buton sözlüğü sınırlı ve tutarlı kalır.
- Üst sınıf sayısı **az** → formlar “her şey her yerde” olmaz.
- Kategori serbest → büyür ama sadece keşif katmanı olduğu için core’u bozmaz.

## 3) H‑OS bu resimde nerede?
- **Contract/FSM**: statü geçişlerinin tek kapısı
- **Policy**: “kim hangi butonu görür/yapar?”
- **Proof/Audit**: “kim ne yaptı?” kanıtı
- **Policy hesapları**: iptal/iade/depozito gibi kuralların tek evi

Pazar tarafı sadece “olayı” üretir; karar ve kanıt H‑OS standardından geçer.

Yetki (role) notu:
- “Rezervasyon operasyonu” ile “kritik karar” farklıdır. Örn:
  - **Ops**: check-in / check-out (staff yapabilir)
  - **Kritik**: iptal / host onayı (ilk versiyon owner-only)
- Bu ayrım, policy ability’lerinde ayrı isimlerle temsil edilmelidir (drift olmasın).

## 4) Uygulama notu (pratik)
- Bir “şey” hem satılık hem rezervasyonlu olacaksa: **iki ayrı ürün/ilan** açılır (flow ayrıdır).  
  İleride bunları “grup/variant” ile ilişkilendirebiliriz; ama core’da karıştırmayız.

## 5) UI standardı (buton adları / tekrar önleyici)
Amaç: Her ekranda farklı buton isimleriyle dağılmamak için “tek sözlük” yaklaşımı.

- Satış (`Order`) için butonlar ayrı; Rezervasyon (`Reservation`) için butonlar ayrı tutulur.
- Her buton bir “Action”dır: `labelTR` + `confirm` + `ability` + `FSM geçişi` + `audit note`.

Sıradaki mikro adımlar (doküman kilidi için):
1) “Action Catalog” (TR) taslağı: Satış 6 aksiyon + Rezervasyon 6 aksiyon
2) Policy ability split: `reservation.ops` vs `reservation.approve/cancel` gibi


