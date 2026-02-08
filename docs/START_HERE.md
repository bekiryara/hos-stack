# START HERE (canonical)

## TL;DR (7 kural)

1. **H-OS = evren hukuku**, **Pazar = ilk ticaret dünyası**
2. **Controller kural yazmaz**: Policy/Contract/Proof → tek kapı (**HosGate** bir kavramdır; kural/policy/contract doğrulama katmanını temsil eder)
3. **Breaking change yok**: Shadow → enforce (direkt enforce yok)
4. **Kanıtsız merge yok**: Test + smoke + proof zorunlu
5. **Küçük patch**: Scratch yok, refactor yok, sadece minimal değişiklik
6. **NO PASS, NO NEXT STEP**: Her adım PASS olmalı, evidence kaydedilmeli
7. **Dokümantasyon güncelle**: Değişiklik yapıyorsan ilgili dokümanı güncelle

---

## Dünya / servis haritası (repo gerçeği)

- **H-OS (core / evren hukuku)**: `work/hos/`
- **Pazar (marketplace world)**: `work/pazar/`
- **Messaging world**: `work/messaging/`
- **Social world**: **planlanan** (repo’da henüz `work/social/` yok)

World registry dokümanları:
- `work/pazar/WORLD_REGISTRY.md`
- `work/messaging/WORLD_REGISTRY.md`

Frontend:
- **Marketplace Web (Vue)**: `work/marketplace-web/`

---

## Günlük komutlar (tek kapı: `.\ops\ops.ps1`)

```powershell
# Sistem
docker compose up -d --build

# Sağlık
.\ops\ops.ps1 verify
.\ops\ops.ps1 conformance
.\ops\ops.ps1 status -Ci

# Yayın (tek yol)
.\ops\ops.ps1 ship
```

---

## Kanıt / evidence (tek dosya)

- Kanıt defteri: `docs/PROOFS/PASS_LOG.md`
- Her anlamlı değişiklikten sonra: koştuğun komutu + sonucu (PASS/FAIL) + (varsa) commit’i bir satır olarak ekle.

---

## “Gelişim nereden takip edilir?”

- **Sürüm**: `VERSION`
- **Değişiklik günlüğü**: `CHANGELOG.md`
- **WP özetleri**: `docs/WP_CLOSEOUTS.md`
- **Mevcut gerçek**: `docs/CURRENT.md`
- **Kural seti**: `docs/RULES.md` + `docs/DEV_DISCIPLINE.md`

