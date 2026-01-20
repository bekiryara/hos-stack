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
- Secrets `secrets/*.txt` dosyalarıdır (gitignore) ve compose `docker-compose.secrets.yml` ile mount edilir.
- Uygulama `*_FILE` değişkenlerini destekler (örn. `JWT_SECRET_FILE`, `DATABASE_URL_FILE`, `POSTGRES_PASSWORD_FILE`).
- Secrets modunda base compose içindeki env’ler override ile boşlanır; böylece `*_FILE` kazanır.

Operasyonel ergonomi:
- `ops/bootstrap.ps1` secrets dosyalarını gerektiğinde üretir ve DB kullanıcı şifresini volume uyumu için senkronlamaya çalışır.
- Secrets modunda compose config doğrulaması, env export gerektirmeden yapılabilir.

## Consequences

### Positive

- Local dev hızlı (env mode) + prod-benzeri güvenli mod (secrets mode).
- CI’da env/secrets iki mod da test edilebilir (compose-smoke).
- Secrets drift/mismatch riski ops bootstrap ile düşer.

### Negative / Risks

- İki mod dokümantasyon/test disiplinini gerektirir.
- “Gerçek secret store” (Vault/GHA secrets standardı) hâlâ ayrı bir büyük adımdır.

## Alternatives considered

- Sadece `.env`: prod secrets lifecycle zayıf kalır.
- Sadece Docker secrets: local ergonomi zorlaşabilir.
- Vault zorunlu: erken aşamada ağır.

## Proof

- Local:
  - Env: `.\ops\bootstrap.ps1` + `.\ops\check.ps1 -SkipAuth`
  - Secrets: `.\ops\bootstrap.ps1 -Secrets` + `docker compose -f docker-compose.yml -f docker-compose.secrets.yml config`
- CI:
  - GitHub Actions `compose-smoke` (env + secrets matrix)


