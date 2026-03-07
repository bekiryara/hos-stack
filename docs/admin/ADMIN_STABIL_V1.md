# ADMIN_STABIL_V1

## Tarih
- 2026-03-07

## Surum Ozeti
- Admin panel temel yonetim operasyonlari stabil hale getirildi.
- Kullanicilar ve uyelikler icin guvenli degisiklik/pasife alma/silme akisleri aktif.
- Turkce arayuz dili ve tutarli islem geri bildirimleri uygulandi.

## Aktif Ekranlar
- Kontrol Merkezi
- Pano
- Kullanicilar
- Uyelikler
- Denetim

## Tamamlanan Islevler
- Login gate ve global cikis
- Platform kullanici listesi + rol guncelleme
- Platform uyelik listesi + rol/durum guncelleme
- Risk bazli onay (dusuk/orta/kritik)
- Kritik islemde ek onay
- Islem sonrasi geri alma (uygun akislarda)
- Kullanici yasam dongusu: `pasife al`, `sil`
- Uyelik yasam dongusu: `pasife al`, `sil`

## Uygulanan Koruma Kurallari
- Son aktif owner kaldirilamaz
- Acik admin oturumu kendi hesabini panelden silemez
- Yetkisiz cagrilar 401 ile engellenir
- Kritik islemler audit kaydi ile izlenir

## Operasyonel Kontrol
- `ops.ps1 refresh -Build`: PASS
- `ops.ps1 verify`: PASS

## Son Admin Commitleri
- `4e046ad` feat(admin): add safe membership deactivate and delete actions
- `811d2eb` feat(admin): add safe deactivate and delete user lifecycle actions
- `d9ba62a` fix(admin): show operation warnings as dismissible notices
- `5d28363` feat(admin): add risk-based confirmations and undo for user operations
- `0bc35a5` feat(admin): turkish UI copy and split control center from dashboard
- `76ea5c8` feat(admin): add safe platform membership edit flow
- `a407f0c` feat(admin): enforce login gate and add global logout/session handling
- `83aab84` feat(admin): add platform memberships read screen and endpoint
- `580bf51` feat(admin): stabilize platform routes and enforce membership consistency

## Bilinen Not
- Admin disi yerel degisiklik: `ops/_checks/pazar_ui_smoke.ps1`
- Bu dosya admin omurgasinin parcasi degildir.

## Sonraki Faz (Faz-2)
- Iki kisi onayi (maker-checker)
- Kritik islem kuyrugu
- Operasyonel rapor/uyari panelinin gelistirilmesi
