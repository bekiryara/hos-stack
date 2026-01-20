# H-OS Remote Failover Politikası (TR) — Kanonik

Amaç: Remote H-OS’a geçerken “remote down olursa ne olur?” sorusunu **tek kanun** olarak kilitlemek.

Bu politika, özellikle iki riski önler:
- **Silent corruption**: remote yokken yanlışlıkla mutation yapılması
- **Drift**: ekiplerin farklı yerlerde farklı “fallback” davranışı kurgulaması

## 1) Terimler
- **Kritik mutation**: para / iptal / status transition / tenant user yönetimi / ürün silme / stok gibi geri dönüşü maliyetli değişiklikler
- **Read-only**: listeleme, detay görüntüleme, allowed-actions gibi “gösterim” işleri (tek başına veri değiştirmez)

## 2) Kanon (en güvenli davranış)
- **Kritik mutation endpoint’leri**: **FAIL-CLOSED**
  - Remote H-OS **gerekiyorsa** ve remote **erişilemiyorsa**: **503 Service Unavailable**
  - Fallback embedded **yok** (enforce modda).
- **Read-only**: **DEGRADE**
  - Remote yoksa:
    - ya embedded’den hesapla (Mod-B/hybrid için),
    - ya boş allowed-actions dön + UI’da “Ops geçici kapalı” mesajı göster.

> Not: “Pazar asla durmasın” hedefi, **kritik mutation’ı yanlış yaparak** sağlanamaz. Kritik mutation’da doğruluk > süreklilik.

## 3) Modlara göre net davranış
### Mod-A: embedded
- Remote yok; her şey embedded.

### Mod-B: hybrid (ölçüm modu)
- Remote çağrıları **shadow** amaçlı yapılabilir.
- Remote down olursa:
  - kritik mutation: embedded authoritative (çünkü remote authoritative değildir)
  - read-only: degrade veya embedded

### Mod-C: remote (authoritative)
- Remote authoritative kabul edilir.
- Remote down olursa:
  - kritik mutation: **503** (fail-closed)
  - read-only: **degrade**

## 4) Rollback mekanizması (tek flag)
- `HOS_MODE=embedded` yap → anında embedded’e dönüş
- (İleri aşama) `HOS_MODE=hybrid` → shadow ölçüm ile güvenli geçiş provası

## 5) Kanıt / kabul kriteri
- Remote down simülasyonunda:
  - kritik mutation endpoint: 503 dönüyor (fallback yok)
  - read-only: 200 dönüyor ama allowed-actions boş veya embedded kaynaklı


