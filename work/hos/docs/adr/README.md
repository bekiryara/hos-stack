# ADR (Architecture Decision Records)

Bu klasör, H-OS için **mimari karar hafızası**dır: “Neden böyle yaptık?” sorusuna kısa ve kalıcı cevaplar.

## Ne zaman ADR yazılır?

- Bir karar **geri dönüşü zor** ise (DB schema yaklaşımı, auth modeli, tenant izolasyon yaklaşımı).
- Birden fazla alternatif varsa ve seçimin gerekçesi ileride unutulacaksa.
- “Bunu niye böyle yaptık?” sorusu gelecekte çıkacaksa.

## Format / isimlendirme

- Dosya adı: `NNNN-kisa-baslik.md` (örn. `0001-api-versioning.md`)
- Şablon: `0000-template.md`

## İçerik standardı

Her ADR şunları içerir:
- **Status**: proposed | accepted | superseded
- **Context**: problem / ihtiyaç
- **Decision**: neyi seçtik?
- **Consequences**: artı/eksi, riskler
- **Alternatives**: kısa liste
- **Proof**: varsa kanıt komutu/CI job’u

## Supersede (yerine geçme)

Yeni karar eskisini geçersiz kılıyorsa:
- Yeni ADR içinde “Supersedes: `NNNN-...`” yaz.
- Eski ADR’nin status’ünü `superseded` yap.


