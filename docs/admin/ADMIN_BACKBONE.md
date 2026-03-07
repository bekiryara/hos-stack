# ADMIN_BACKBONE

## 1. Amac
- H-OS admin panelinin buyurken dagilmamasini saglamak.
- If/else cehennemi olusturmadan net, izole ve surdurulebilir bir yapi korumak.
- Kritik islemlerde guvenlik ve geri alinabilirlik standardini zorunlu kilmak.

## 2. Kapsam
- Klasor: `work/hos/services/web/src/features/admin`
- API omurgasi: `work/hos/services/api/src/routes/v1/admin_platform.js`

## 3. Temel Mimari Kurallar
- Tek is tek yerde cozulur: ayni davranisin ikinci yolu acilmaz.
- Ekran dosyalari sadece ekran davranisini tutar.
- Is kurallari tekrar kullanilabilir ortak katmanda toplanir.
- Her kritik islem ayni kalibi izler: `onay -> uygulama -> audit -> geri alma`.

## 4. Dosya Disiplini
- `pages/`: yalniz ekran akislar.
- `api/`: yalniz admin API cagrilari.
- `utils/`: ortak guvenlik/onay/hata yardimcilari.
- `layout/`: yalniz sayfa kabugu ve gezinme.
- Yeni dosya eklemeden once mevcut klasorde tekrar kullanilabilir yapi aranir.

## 5. Islem Siniflari
- Dusuk risk: standart tek onay.
- Orta risk: guclu onay (etki metni ile).
- Kritik risk: cift onay (ek onay metni/sinyali).

## 6. Zorunlu Guvenlik Kurallari
- Son aktif owner kaldirilamaz.
- Acik admin oturumu kendi hesabini panelden silemez.
- Kritik degisiklikler audit kaydi olmadan tamamlanamaz.
- Silme mumkunse pasife alma adimi ile baslar.

## 7. UI/UX Standartlari
- Tum yonetim metinleri Turkce ve net olur.
- Teknik hata kodu dogrudan son kullaniciya birincil metin olarak verilmez.
- Islem uyarilari kapanabilir ve gecici gorunur.
- Basari/uyari/hata kutulari tum ekranlarda ayni davranir.

## 8. Geri Alma Politikasi
- Rol ve uyelik degisikliklerinde hizli geri alma aksiyonu bulunur.
- Kalici silme geri alinamaz; bunu acikca belirtmek zorunludur.
- Kritik islemlerde geri donus adimi audit ile izlenir olmalidir.

## 9. Gelistirme Akisi
- Kucuk parca degisiklik.
- Tek amacli commit.
- Her adimdan sonra `refresh -Build` ve `verify`.
- Basarisiz testte yeni ozellik degil, once duzeltme.

## 10. Faz Yonetimi
- Faz-1: Stabil admin cekirdegi (tamamlandi).
- Faz-2: Iki kisi onayi (maker-checker) ve kritik islem kuyrugu.
- Faz-3: Operasyonel dashboard ve politika otomasyonu.

## 11. Degisiklik Kabul Kurali
- Bu belgeye aykiri bir cozum merge edilmez.
- Istisna gerekiyorsa sebep ve gecerlilik suresi yazili olarak eklenir.
