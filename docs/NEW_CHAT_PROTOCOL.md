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

# 3 AJAN ILE HIZLI GELISIM (ROL + SCOPE)

Amaç: Hizli gelisim ama kaos yok. Her ajan sadece kendi alaninda calisir.

ALTIN KURAL:
- Her ajan ayni anda sadece 1 WP alir (tek is).
- Ayni dosya/klasore ayni anda 2 ajan girmez.
- Ajanlar publish etmez; yayin istenirse sadece ops/ship_main.ps1 yolu kullanilir.

## AJAN-1: FRONTEND (MARKETPLACE UX)
- Dokunur: `work/marketplace-web/**`
- Yapmaz: backend/ops/doc workflow degisikligi
- Cikti: degisen dosyalar + kisa test adimi + (varsa) proof notu

## AJAN-2: BACKEND (PAZAR / LARAVEL)
- Dokunur: `work/pazar/**` (ozellikle `routes/api/**`, middleware, migrations)
- Yapmaz: frontend/ops/disiplin workflow degisikligi
- Cikti: degisen dosyalar + contract etkisi + kisa test adimi + (varsa) proof notu

## AJAN-3: OPS / GATES / RELEASE
- Dokunur: `ops/**` ve gerekli ise `docs/runbooks/**`
- Yapmaz: urun/UX feature ekleme, yeni publish yolu uretme
- Cikti: hangi gate/komut etkilendi + beklenen PASS/FAIL davranisi + runbook notu

---

# AJAN SISTEMI (ADIM ADIM, ACELE ETMEDEN)

## Adim 0 — Hedef
- Hiz + kaossuz ilerleme
- Minimal diff
- Tek yayin yolu: `ops/ship_main.ps1`
- WP kapanisi: proof + closeout + changelog disiplini

## Adim 1 — Scope kilidi (en kritik)
- AJAN-1 (Frontend): `work/marketplace-web/**`
- AJAN-2 (Backend/Pazar): `work/pazar/**`
- AJAN-3 (Ops/Docs): `ops/**` ve gerekirse `docs/runbooks/**` + `docs/PROOFS/**`

Kural: Ayni klasore ayni anda 2 ajan girmez.

## Adim 2 — Her ajana ayni “is sozlesmesi” formatini uygula
- Okuma: `docs/NEW_CHAT_PROTOCOL.md` + `docs/DEV_DISCIPLINE.md`
- Scope: “Sadece su path’lere dokun: …”
- Yasaklar: refactor yok, yeni workflow yok, publish yok
- Cikis formati:
  - Degisen dosyalar (liste)
  - Neden (1-2 cumle)
  - Test/proof adimi (kisa)

## Adim 3 — WP yonetimi (hiz icin kucuk paket)
- Her ajan tek seferde 1 WP alir.
- WP tanimi 5 satir: Goal / In-scope paths / Out-of-scope / Test plan / Closeout artifacts

## Adim 4 — Koordinasyon ritmi (tek kapi: insan)
- Ajanlar isi hazirlar
- Insan kontrol eder
- Yayin istenirse: insan `ops/ship_main.ps1` calistirir

## Adim 5 — Baslangic (sistemi test etmek icin)
1 hafta sadece kucuk WP’ler:
- Frontend: 1 kucuk UX duzeltme
- Pazar: 1 kucuk endpoint/contract duzeltme
- Ops: 1 gate/runbook netligi

---

# KOPYALA-YAPISTIR: 3 AJAN PROMPTU (TEK DOSYADAN YONETIM)

Kullanim:
- Yeni ajan sohbetine su dosyayi okut: `docs/NEW_CHAT_PROTOCOL.md`
- Sonra ajana sadece sunu yaz: "Sen AJAN-1'sin" (veya 2/3)
- Ardindan asagidaki ilgili promptu aynen yapistir.

## AJAN-1 PROMPT (FRONTEND / MARKETPLACE UX)

CONTEXT
- Repo disiplini: WP tabanli, minimal diff, fail-fast gates, proof + closeout.
- Publish yolu: sadece `ops/ship_main.ps1` (ajan publish ETMEZ).

SCOPE
- Sadece: `work/marketplace-web/**`
- Dokunma: `ops/**`, `work/pazar/**`, `work/hos/**`, `work/messaging/**`, `docs/WP_CLOSEOUTS.md`, `CHANGELOG.md` (ozellikle istenmedikce)

OUTPUT (ZORUNLU)
1) Degisen dosyalar listesi
2) Neden (1-2 cumle)
3) Test/proof adimi (kisa)

## AJAN-2 PROMPT (BACKEND / PAZAR-LARAVEL)

CONTEXT
- Repo disiplini: WP tabanli, minimal diff, fail-fast gates, proof + closeout.
- Publish yolu: sadece `ops/ship_main.ps1` (ajan publish ETMEZ).

SCOPE
- Sadece: `work/pazar/**`
- Dokunma: `ops/**`, `work/marketplace-web/**`, `work/hos/**`, `work/messaging/**`, `docs/WP_CLOSEOUTS.md`, `CHANGELOG.md` (ozellikle istenmedikce)

OUTPUT (ZORUNLU)
1) Degisen dosyalar listesi
2) Contract/semantik etkisi (1-2 cumle)
3) Test/proof adimi (kisa)

## AJAN-3 PROMPT (OPS / GATES / DOCS-PROOF)

CONTEXT
- Repo disiplini: WP tabanli, minimal diff, fail-fast gates, proof + closeout.
- Publish yolu: sadece `ops/ship_main.ps1` (ajan publish ETMEZ).

SCOPE
- Sadece: `ops/**` ve gerekirse `docs/runbooks/**` + `docs/PROOFS/**`
- Dokunma: urun/UX feature ekleme, yeni publish yolu uretme, genis refactor

OUTPUT (ZORUNLU)
1) Degisen dosyalar listesi
2) Hangi gate/komut etkilendi (PASS/FAIL beklentisi)
3) Runbook/proof notu (kisa)

---

# WP SABLONU (5 SATIR, KAPANABILIR)

WP-XXX: <Kisa baslik>
- Goal: <tek cumle>
- In-scope paths: <or. work/marketplace-web/**>
- Out-of-scope: <dokunulmayacak yerler>
- Test plan: <hangi komutlar/URL>
- Closeout artifacts: <proof + (varsa) closeout/changelog>
---