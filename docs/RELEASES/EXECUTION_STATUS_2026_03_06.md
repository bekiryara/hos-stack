# Execution Status - 2026-03-06

## 1) Tamamlananlar (repo gercegi)

- Deterministik policy primitive omurgasi create/edit tarafinda aktif:
  - `pricing_strategy`, `billing_model`, `service_time_model`, `location_scope` varyant bazli okunuyor.
- Pricing engine v1 aktif:
  - `unit_price`, `multiplier`, `subtotal` hesaplama omurgasi var.
- Rental/Reservation kalici pricing snapshot aktif:
  - `rentals` + `reservations` icin `totals_json` yaziliyor.
  - Detail/panel okumasi `totals_json` ustunden, eski sentetik `multiplier=1` fallback kaldirildi.
- UI standardizasyonu:
  - Ortak fiyat karti (`PricingSummary`) create success + detail ekranlarinda tek dilde calisiyor.
- Listing search kontrati sade:
  - Backend `attrs[...]` kapandi, sadece `filters[...]` kabul ediliyor (attrs -> 422).
  - Frontend query hydration da `filters` odakli (legacy `f_*` fallback kaldirildi).
- Error middleware sade:
  - `ErrorEnvelope` icindeki kullanilmayan legacy donusum dali temizlendi.

## 2) Bugun dogrulanan checkler

- `ops/_checks/listing_contract_check.ps1` -> PASS
- `ops/_checks/order_contract_check.ps1` -> PASS
- `ops/_checks/rental_contract_check.ps1` -> PASS
- `ops/_checks/reservation_contract_check.ps1` -> PASS
- `ops/_checks/account_portal_read_check.ps1` -> PASS
- `npm run build` (marketplace-web) -> PASS

## 3) Acik kalanlar / dikkat

- `docs/CURRENT.md` alt bolumlerinde eski `attrs[...]` compatible anlatimi hala geciyor.
  - Ust "Recent Updates" bolumu dogru, alt contract anlatiminda text drift var.
- Check scriptleri (ozellikle order contract) test verisi uretiyor.
  - Kosu sonrasi otomatik cleanup disiplini her scriptte standart degil.

## 4) Siradaki mantikli gelisim adimlari (deterministik)

### Adim A - Docs drift kapatma (oncelik 1)
- Hedef:
  - `docs/CURRENT.md` icindeki listing search contract metnini filters-only gercegi ile hizalamak.
- Teslim kriteri:
  - Ayni dosyada "attrs destekleniyor" celiskisi kalmayacak.

### Adim B - Check test-veri hijyeni (oncelik 2)
- Hedef:
  - `order_contract_check` ve benzeri scriptlerde test kaydi birikmesini onlemek.
  - Ya test tenant/listing izolasyonu, ya kosu-sonrasi deterministic cleanup.
- Teslim kriteri:
  - Check kosusu sonrasi panelde test siparisi birikmeyecek.

### Adim C - Faz 3 devam (oncelik 3)
- Hedef:
  - Frontend API katmaninda legacy hata parse tekrarlarini sadeleştirmek (davranis bozmadan).
- Teslim kriteri:
  - Build PASS + listing/order/rental/reservation contract check PASS.

## 5) Uygulama disiplini

- Her adim sonunda:
  1. Ilgili checkleri kos
  2. `docs/CURRENT.md` ve bu dosyada not guncelle
  3. Tek amacli temiz commit at

