# H-OS ↔ Pazar (Tek Repo) — En Mantıklı Entegrasyon

Bu doküman “H-OS evren hukuku / Pazar ticaret sahnesi” yaklaşımını **kod seviyesinde** nasıl kilitlediğimizi açıklar.

## Amaç
- Pazar büyürken controller/model içinde if-else patlamasını engellemek
- Yetki/kurallar/kanıt üretimini tek yerde toplamak
- Mikroservise erken bölmeden, **tek repo/tek deploy** ile ilerlemek

## Kural
Pazar domain akışları (order/reservation/payment) çalışır; ama:
- “Bu yapılabilir mi?” → H-OS Policy
- “Bu sözleşme geçerli mi / hangi state geçişi?” → H-OS Contract (sonraki adım)
- “Bu olay delil mi?” → H-OS Proof

## Kod haritası (şu an)
- `app/Hos/Hos.php`: giriş noktası
- `app/Hos/Policy/PolicyEngine.php`: policy iskeleti (şimdilik minimal)
- `app/Hos/Proof/ProofRecorder.php`: kanıt/audit katmanı
- `app/Providers/HosServiceProvider.php`: container binding
- `app/Support/HosGate.php`: kolay çağırım (`HosGate::proof()...`)

## İlk entegrasyon (kanıt)
Örnek: Public order cancel akışı artık “kanıt kaydı”nı H-OS üzerinden yazar:
- `HosGate::proof()->statusChange(...)`

Bu, “evrensel defter”in ilk gerçek kullanım örneğidir.

## Sonraki adım (Faz)
Contract/FSM katmanını H-OS’a taşırken hedef:
- `HosGate::contract($order)->transition('cancelled', ['tenant_id' => ..., 'user_id' => ..., 'source' => ...])`

Not: Bu faz artık başladı — order/reservation/payment status geçişleri **Contract/FSM üzerinden** yazılıyor ve proof otomatik üretiliyor.
- Terminal state kuralları + rollback planı + versiyonlu sözleşme


