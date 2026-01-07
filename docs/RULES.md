# RULES

1. **Scratch yok**: Yeni özellik ekleme, büyük refactor yapma
2. **Küçük patch**: Sadece minimal, gerekli değişiklik
3. **Proof zorunlu**: Her değişiklik için test/smoke/proof kanıtı
4. **NO PASS, NO NEXT STEP**: Adım PASS olmadan devam etme
5. **Controller kural yazmaz**: Business logic → `HosGate`, controller sadece UI
6. **Shadow → enforce**: Breaking change için önce shadow, sonra enforce
7. **Kanıtsız merge yok**: PR'da proof olmadan merge yok
8. **Dokümantasyon güncelle**: Değişiklik yapıyorsan ilgili dokümanı güncelle
9. **Secrets korumalı**: `.gitignore`'da secrets var, asla commit etme
10. **Stack bozma**: Değişiklik yaparken çalışan stack'i bozma

