# 0004 — Contract Governance: CI Contract Checks for `/v1`

- Status: accepted
- Date: 2025-12-26
- Owner: TBD

## Context

API büyüdükçe “gizli breaking change” riski artar. Versiyonlama tek başına yeterli değildir; PR aşamasında sözleşmenin kırılmadığını kanıtlamak gerekir.

## Decision

- `/v1` için minimal ama net bir **contract test** seti tutulur.
- Bu testler CI’da ayrı bir job olarak çalışır: **`contract-check`**.
- Legacy endpoint’lerin deprecation sinyali (header) contract kapsamındadır.

## Consequences

### Positive

- Breaking change’ler PR aşamasında yakalanır.
- Contract testler “hafıza” görevi görür (bu endpoint’ler var olmalı).

### Negative / Risks

- Testlerin kapsamı çok dar kalırsa sahte güven üretir; zamanla kapsam artırılmalı.
- OpenAPI gibi bir formal spec’e geçiş ileride gerekebilir.

## Alternatives considered

- Sadece manuel dokümantasyon: drift kaçınılmaz.
- Tam OpenAPI first: erken aşamada ağır; ileride değerlendirilebilir.

## Proof

- Local:
  - `cd services/api && npm run contract`
- CI:
  - GitHub Actions: `contract-check`


