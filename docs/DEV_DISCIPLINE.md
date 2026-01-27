# GELISTIRME DISIPLINI (DEGISMEZ)

Amac:
- Mevcut sistemi bozmadan, WP tabanli (is paketi) gelistirme.
- Disiplin sohbetten degil, repodan okunur.

Temel Kurallar:
- Tek seferde tek is.
- Once analiz -> sonra plan -> onay -> en son kod.
- Minimal diff (az degisiklik), sifir gurultu.
- main (ana dal) gelistirme yeri degildir; sadece sonuc dalidir.

TEK MAIN / TEK YAYIN YOLU:
- Gunluk calisma yerel olabilir, ancak main'e yayin ops/ship_main.ps1 ile yapilir.
- ship_main zorunlu kilar: main branch, temiz working tree, gates fail-fast calistir, sonra pull --rebase ve push.
- Gates sirasi: secret_scan -> public_ready_check -> repo_payload_guard -> closeouts_size_gate -> conformance -> frontend_smoke -> prototype_smoke -> prototype_flow_smoke (varsa).
- WP kapanisinda: proof dokumani olustur (docs/PROOFS/wpXX_*.md), docs/WP_CLOSEOUTS.md'ye entry ekle (Purpose, Deliverables, Commands, Proof, Key Findings), CHANGELOG.md'ye entry ekle (### WP-XX: Title (tarih) formatinda, **bold** section'lar ile).

Roller:
- Cursor: Sadece dosya duzenler ve komut onerir. Git islemi YAPMAZ.
- Insan: git branch/commit/push/merge islemlerini yapar.

Gates (kontrol kapilari):
- main'e cikis sadece kontroller PASS (gecer) ise yapilir.
- PASS degilse yayin yok, once sebep bulunur.

Not:
- Bu dosya okunmadan yeni sohbet/ajan calismaya baslamaz.
---