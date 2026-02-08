# ADR (Architecture Decision Records)

Bu klasör, H-OS için **mimari karar hafızasıdır**: “Neden böyle yaptık?” sorusuna kısa, net ve kalıcı cevap verir.
ADR’ler; tartışmayı bitiren, ileride geri dönüp doğrulanabilen karar kayıtlarıdır.

## Amaç

- **Tek cümleyle**: Kararı, gerekçesini ve sonuçlarını görünür kılmak.
- **Ne değildir?**: Uzun tasarım dokümanı, yapılacaklar listesi veya değişiklik günlüğü değildir.

## Ne zaman ADR yazılır?

Aşağıdaki durumlardan biri varsa ADR yaz:

- **Geri dönüşü zor karar**: auth modeli, tenant izolasyon yaklaşımı, DB şeması/stratejisi, token/cookie posture vb.
- **Birden çok makul alternatif**: seçim yapılmazsa drift/duality oluşacaksa.
- **Sözleşmeye etki**: endpoint contract, hata zarfı, idempotency davranışı gibi dış yüzeyi etkileyen karar.
- **Ops/CI standardı**: çalıştırma yolu, gate’ler, proof standardı gibi “tek doğru yol” kuralı.

## Ne zaman ADR yazılmaz?

- Yalnızca bir bug fix / küçük refactor ve **karar** yoksa.
- Tamamen geçici/deneysel değişiklikse (o zaman PR açıklaması veya issue notu yeterli olabilir).

## Dosya adlandırma ve sıra

- **Format**: `NNNN-kisa-baslik.md`
- **Örnek**: `0001-api-versioning.md`
- **Kural**: NNNN sıralı artar (0001, 0002, …). Başlık kısa ve arama-dostu olsun.

## İçerik standardı (minimum şablon)

Her ADR aşağıdaki bölümleri içermelidir:

- **Status**: `proposed | accepted | superseded`
- **Context**: Problem/İhtiyaç (1–2 paragraf)
- **Decision**: Seçim (mümkünse maddeli, net)
- **Consequences**: Artılar/eksiler, riskler, trade-off
- **Alternatives**: En az 1 alternatif + neden seçilmedi
- **Proof**: Varsa kanıt komutu/CI gate; kanıtların kanonik kaydı: `docs/PROOFS/PASS_LOG.md`

Not: Şablon için `0000-template.md` dosyasını kullan.

## Supersede (yerine geçme) kuralı

Yeni karar eski bir ADR’yi geçersiz kılıyorsa:

- Yeni ADR’ye şu satırı ekle: **`Supersedes: NNNN-...`**
- Eski ADR’de **Status** alanını `superseded` yap.
- Mümkünse “ne değişti?”yi yeni ADR’nin Consequences bölümünde 1 paragrafla özetle.

## Kalite kontrol (okunabilirlik checklist’i)

- Kararı 30 saniyede anlayabiliyor musun?
- “Neden?” tek paragrafta açıklanıyor mu?
- Alternatifler gerçekten alternatif mi (ve neden elendiği yazıyor mu)?
- Uygulamada nerelerin etkilendiği belli mi (contract/ops/CI)?
- Proof referansı var mı (varsa PASS_LOG’da izi var mı)?


