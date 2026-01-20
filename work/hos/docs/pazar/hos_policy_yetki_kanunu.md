# H-OS Policy (Yetki Kanunu) — TR

Bu doküman “kim neyi yapabilir?” sorusunu H-OS tarafında **tek kanun** olarak tanımlar.

## Amaç
- Yetkileri controller/middleware içine gömmemek
- Kuralları versiyonlamak (`HOS_POLICY_VERSION`)
- Shadow → Enforce ile kopmadan geçmek

## Modlar
- **off**: policy hesaplanmaz
- **shadow** (varsayılan): policy hesaplanır, istenirse loglanır; **bloklamaz**
- **enforce**: policy reddederse **403** döner

Env:
- `HOS_POLICY_MODE=shadow|enforce|off`
- `HOS_POLICY_LOG=true|false`
- `HOS_POLICY_VERSION=...`

## Canonical ability isimleri
Pazar ile H-OS arasında değişmez (API sözleşmesi):
- `admin.tenants.manage`
- `tenant.product.write`
- `tenant.product.delete`
- `tenant.stock.manage`
- `tenant.order.manage`
- `tenant.order.cancel` (kritik)
- `tenant.reservation.manage`
- `tenant.reservation.ops` (ops)
- `tenant.reservation.cancel` (kritik)
- `tenant.reservation.confirm` (kritik)
- `tenant.payment.manage`
- `tenant.payment.mark_paid` (kritik)
- `tenant.payment.cancel` (kritik)
- `tenant.users.manage`
- `tenant.audit.read`
- `public.order.create`
- `public.order.cancel`
- `public.reservation.create`
- `public.reservation.cancel`
- `public.payment.intent.create`
- `public.payment.cancel`

## Rol matrisi (Pazar için başlangıç)
- **super_admin**
  - tüm ability’ler: ✅
- **tenant owner**
  - `tenant.product.write`: ✅
  - `tenant.product.delete`: ✅
  - `tenant.stock.manage`: ✅
  - `tenant.order.manage`: ✅
  - `tenant.order.cancel`: ✅
  - `tenant.reservation.manage`: ✅
  - `tenant.reservation.ops`: ✅
  - `tenant.reservation.cancel`: ✅
  - `tenant.reservation.confirm`: ✅
  - `tenant.payment.manage`: ✅
  - `tenant.payment.mark_paid`: ✅
  - `tenant.payment.cancel`: ✅
  - `tenant.users.manage`: ✅
  - `tenant.audit.read`: ✅
- **tenant staff**
  - `tenant.product.write`: ✅
  - `tenant.product.delete`: ❌
  - `tenant.stock.manage`: ❌
  - `tenant.order.manage`: ❌
  - `tenant.order.cancel`: ❌
  - `tenant.reservation.manage`: ✅
  - `tenant.reservation.ops`: ✅
  - `tenant.reservation.cancel`: ❌
  - `tenant.reservation.confirm`: ❌
  - `tenant.payment.manage`: ❌
  - `tenant.payment.mark_paid`: ❌
  - `tenant.payment.cancel`: ❌
  - `tenant.users.manage`: ❌
  - `tenant.audit.read`: ❌

## Şu anki durum
Policy fazı başlatıldı ve ilk canary entegrasyon:
- Panel ürün CRUD + panel order/reservation/payment update + tenant users + audit erişiminde policy **shadow** check çalışıyor.
- Public tarafta order/reservation/payment create/cancel işlemlerinde policy **shadow** check çalışıyor.
- Davranış değişmiyor (shadow).

## Sonraki adım
En büyük drift riskini azaltan sıradaki mikro-adımlar:
- **Allowed-actions (UI kanonu)**: UI butonları server’dan gelen `allowedActions` listesinden çizsin (Policy ∩ Contract).
- **Shadow → Enforce planı**: önce birkaç kritik ability için shadow log’u aç, sonra sadece o ability’lerde enforce’a geç.
- **Ability kapsamı**: “manage” çok genişse, ops/kritik ayrımıyla granular ability ekleyip bu dokümana kilitle.


