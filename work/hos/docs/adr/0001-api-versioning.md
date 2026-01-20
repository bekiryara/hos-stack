# 0001 — API Versioning: `/v1` + Legacy Compatibility

- Status: accepted
- Date: 2025-12-26
- Owner: TBD

## Context

H-OS çekirdeği büyüdükçe API yüzeyi de büyüyecek. Sürümleme olmadan:
- breaking değişiklikler istemeden client’ları kırar,
- rollback/release yönetimi zorlaşır,
- dokümantasyon ve testler drift eder.

Aynı zamanda mevcut “legacy” endpoint’leri kullanan erken kullanıcılar/araçlar vardır; ani kırılma istemiyoruz.

## Decision

- Public API **versiyonlu** olacak: **`/v1/...`**.
- Geriye uyumluluk için legacy (unversioned) endpoint’ler bir süre daha çalışır.
- Legacy endpoint’ler response’larda **deprecation sinyali** taşır:
  - `Deprecation: true`
  - `Sunset: <HTTP-date>` (örn. `Thu, 31 Dec 2026 00:00:00 GMT`)
  - Sunset tarihi `LEGACY_SUNSET` env ile konfigüre edilir (default: `2026-12-31`).

## Consequences

### Positive

- Breaking change’ler kontrollü hale gelir (v1 sözleşmesi netleşir).
- Dokümantasyon/test/CI standardı `/v1` etrafında kurulur.
- “Legacy” tüketiciler için geçiş süresi sağlanır.

### Negative / Risks

- İki route ağacı (legacy + v1) bakım maliyeti getirir.
- Sunset tarihi belirlenmezse legacy “sonsuz” kalabilir.

## Alternatives considered

- Sürümleme yok (monolith API): erken dönemde hızlı ama orta vadede kırılgan.
- Header tabanlı sürümleme: client/ops karmaşıklığı artar.
- Semver tabanlı `/v1.1`: gereksiz ayrıntı; v1 yeterli.

## Proof

- Local:
  - `.\ops\smoke.ps1` (v1 endpoint’leriyle uçtan uca doğrular)
  - `.\ops\check.ps1 -SkipAuth` (health/ready/metrics)
- CI:
  - GitHub Actions `CI` workflow (api tests + compose-smoke)


