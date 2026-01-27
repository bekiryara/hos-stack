# YENI SOHBET / YENI AJAN BASLANGICI (KOPYALA-YAPISTIR)

Bu projede hafiza sohbette degil repodadir.

1) Once su dosyalari oku:
- docs/DEV_DISCIPLINE.md
- docs/RULES.md
- docs/WP_CLOSEOUTS.md
- docs/CODE_INDEX.md

2) Sifir hafiza varsay:
- Onceki sohbetleri bilmedigini kabul et.

3) Davranis:
- Yeni sistem / mimari onermeyeceksin.
- Sadece mevcut sistemi hizalayacaksin.
- Once analiz yap, sonra minimal plan yaz, onay almadan kod/prompt yazma.

4) Nereden devam:
- docs/WP_CLOSEOUTS.md icinde en son kapanan WP'den devam et.

NEW CHAT CHECKLIST:
- Uc disiplin dosyasini oku (.cursorrules, docs/DEV_DISCIPLINE.md, docs/NEW_CHAT_PROTOCOL.md).
- Mevcut durumu docs/WP_CLOSEOUTS.md son entry'den tespit et (en son kapanan WP'yi bul).
- Yeni sistem onerme.
- WP kapanisinda: proof dokumani olustur (docs/PROOFS/wpXX_*.md), docs/WP_CLOSEOUTS.md'ye entry ekle (mevcut format: Purpose, Deliverables, Commands, Proof, Key Findings), CHANGELOG.md'ye entry ekle (### WP-XX: Title (tarih) formatinda, **bold** section'lar ile).
- Yayin istenirse: ops/ship_main.ps1 kullan (gates PASS sonrasi otomatik pull --rebase ve push).
---