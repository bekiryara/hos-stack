# H-OS POLICY GATE — “TEK KAPI” KANONU (Pazar İçin) (TR)

Amaç: Pazar dünyasında **kim neyi yapabilir?** kararının drift etmesini (UI başka, controller başka) engellemek.

Bu doküman “H‑OS’u Pazar’a uyarlama” için **kanonik uygulama standardıdır**.

## 0) Kısa tanım

- **UI hukuk değildir.** UI sadece server’ın söylediğini çizer.
- **Hukuk (yetki) sadece server’dadır.** Her kritik mutation endpoint’i **Policy Gate**’ten geçer.
- Status değişimleri **tek mutation kapısı** olan `Contract/FSM` ile yapılır.
- Status proof’u `transition()` ile otomatik oluşur (append-only).

## 1) Kural (Final)

Tüm kritik mutation endpoint’lerinde:
1) Subject resolve edilir (order / reservation / payment / …) + tenant scope garanti edilir  
2) Subject resolve sonrası **ilk business satırı** Policy Gate olur  
3) Policy geçmeden hiçbir mutation çalışmaz  

## 2) Pazar’daki gerçek API (bugün)

- Policy Gate (kanonik): `App\Support\HosGate::policyEnforcer()->checkEnforce(...)`
- Policy Gate (mode-aware): `App\Support\HosGate::policyEnforcer()->check(...)`
- Contract/FSM: `App\Support\HosGate::contract($subject)->transition(...)`
- Proof/Audit: `App\Support\HosGate::proof()->statusChange(...)` (transition içinde çağrılır)

Policy modları (tek kaynak):
- `config/hos.php`
  - `HOS_POLICY_MODE=off|shadow|enforce` (default: enforce)
  - `HOS_POLICY_LOG=true|false`

## 3) Kanonik örnek (Tenant Order Cancel)

> Not: Ability isimleri kanoniktir: `App\Hos\Policy\Abilities::*`

```php
// 1) SUBJECT RESOLVE (tenant scope zorunlu)
$order = Order::query()
    ->where('tenant_id', $tenant->id)
    ->where('id', $orderId)
    ->firstOrFail();

// 2) POLICY GATE (subject resolve sonrası ilk business satırı)
HosGate::policyEnforcer()->checkEnforce(Auth::user(), Abilities::TENANT_ORDER_MANAGE, $order, [
    'tenant_id' => $tenant->id,
    'route' => 'ui.tenant.orders.cancel',
    'ip' => $request->ip(),
]);

// 3) CONTRACT / FSM = tek mutation kapısı
HosGate::contract($order)->transition('cancelled', [
    'tenant_id' => $tenant->id,
    'user_id' => Auth::id(),
    'source' => 'ui',
    // opsiyonel: note/reason
    // 'note' => '...',
]);

// 4) Controller ekstra domain mutation YAPMAZ.
// 5) Proof/Audit status değişimi transition() içinde otomatik yazılır.
```

## 4) Shadow → Enforce disiplini

- Shadow: davranışı değiştirmeden ölç/izle (log/metric).  
  - `HOS_POLICY_MODE=shadow`
  - (opsiyonel) `HOS_POLICY_LOG=true`
- Enforce: Policy deny ise 403 döndürür.  
  - `HOS_POLICY_MODE=enforce`

> Kural: Shadow’dan enforce’a geçiş, “kritik endpoint listesi” üzerinden kademeli yapılır.

## 5) Allowed Actions (UI kanonu)

UI butonları **role/status if’leriyle** karar vermemelidir. UI sadece server’ın döndürdüğü “allowed actions” listesini render eder.

Kanonik tanım:

\[
\text{AllowedActions} = \text{Policy(can)} \cap \text{Contract(canTransition)}
\]

Bu repo’da (Pazar) önerilen yapı:
- `ActionResolver::for($actor, $subject)` → `['cancel', 'mark_paid', ...]`
- UI: sadece bu listedeki aksiyonları gösterir.

> Not: Allowed-actions UI drift’ini azaltır; fakat server tarafında Policy Gate + Contract Gate **zorunludur** (UI’ya güvenilmez).

## 6) “Kritik endpoint” tanımı

Kritik = veri değiştiren ve kullanıcıya “işletme sonucu” üreten her şey:
- Status geçişleri (cancel/confirm/check-in/complete/mark-paid)
- Ödeme durumu değişimi
- Tenant user yönetimi
- Ürün silme / stok gibi kritik değişiklikler

Bu endpoint’ler Policy Gate’ten geçmek zorundadır.


