# 0003 — Secrets Standard: Env Mode + Docker Secrets (`*_FILE`) Mode

- Status: accepted
- Date: 2025-12-26
- Owner: TBD

## Context

H-OS hem hızlı local dev (kolay başlangıç) hem de prod-benzeri güvenlik yaklaşımı (secrets lifecycle) hedefliyor.
Bu yüzden tek bir “secrets mekanizması” yeterli değil; iki net modun karışmadan çalışması gerekiyor.

Riskler:
- secrets’in yanlışlıkla git’e girmesi
- env + secrets karışımıyla DB auth mismatch (28P01)
- CI ve dokümanların drift etmesi

## Decision

İki açık mod tanımladık:

1) **Env mode**
- Secrets `.env` içindedir (gitignore).
- Basit local kullanım için varsayılan/kolay mod.

2) **Docker secrets mode**
- Secrets `work/hos/secrets/*.txt` dosyalarıdır (gitignore) ve **root** `docker-compose.yml` tarafından Docker secrets olarak mount edilir.
- Uygulama `*_FILE` değişkenlerini destekler (örn. `JWT_SECRET_FILE`, `DATABASE_URL_FILE`, `POSTGRES_PASSWORD_FILE`).
- Stack wiring’de varsayılan olarak `*_FILE` kazanır (compose içinde ilgili plain env değerleri bilinçli olarak boş bırakılır).

Operasyonel ergonomi:
- Secrets dosyaları kanonik araç ile üretilebilir: `.\ops\ops.ps1 secrets-from-env -Apply`
- Tek kanonik start: `docker compose up -d --build`

## Consequences

### Positive

- Local dev hızlı (env mode) + prod-benzeri güvenli mod (secrets mode).
- CI’da env/secrets iki mod da test edilebilir (pipeline gates + test matrix yaklaşımı).
- Secrets drift/mismatch riski kanonik ops araçları ve sözleşme kontrolleri ile düşer.

### Negative / Risks

- İki mod dokümantasyon/test disiplinini gerektirir.
- “Gerçek secret store” (Vault/GHA secrets standardı) hâlâ ayrı bir büyük adımdır.

## Alternatives considered

- Sadece `.env`: prod secrets lifecycle zayıf kalır.
- Sadece Docker secrets: local ergonomi zorlaşabilir.
- Vault zorunlu: erken aşamada ağır.

## Proof

- Local:
  - Secrets (canonical): `.\ops\ops.ps1 secrets-from-env -Apply` + `docker compose up -d --build` + `.\ops\ops.ps1 status`
- CI:
  - GitHub Actions `CI` workflow (ops gates + tests)


