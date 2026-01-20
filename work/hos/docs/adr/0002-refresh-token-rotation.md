# 0002 — Persistent Sessions: Refresh Token Rotation via HttpOnly Cookie

- Status: accepted
- Date: 2025-12-26
- Owner: TBD

## Context

Kısa ömürlü access token (JWT) iyi bir güvenlik pratiği olsa da kullanıcı deneyiminde “sık login” sorunu yaratır.
Browser tabanlı client’larda refresh token’ı güvenli saklamak kritik bir ihtiyaçtır.

Tehditler:
- XSS durumunda localStorage’daki token’ların çalınması
- refresh token reuse (çalınan token ile uzun süre erişim)

## Decision

- Access token: kısa ömürlü JWT (Authorization: Bearer).
- Refresh token: **HttpOnly cookie** (`hos_refresh`) içinde tutulur.
- Refresh endpoint: `POST /v1/auth/refresh`
  - refresh token **rotate edilir** (yeni token üretilir, eskisi invalid olur).
- Logout endpoint: `POST /v1/auth/logout`
  - refresh token revoke edilir, cookie temizlenir.
- Cookie `Secure` davranışı prod proxy/HTTPS senaryolarına uyumlu olacak şekilde kontrol edilir (`COOKIE_SECURE` / `x-forwarded-proto`).

## Consequences

### Positive

- Client tarafında refresh token JS ile okunamaz (HttpOnly).
- Token rotation, refresh token reuse riskini azaltır.
- Logout gerçek anlamda session invalidation sağlar.

### Negative / Risks

- Cookie/poxy/TLS yanlış konfigürasyonu refresh flow’u bozabilir (Secure flag, domain, path).
- Tam reuse detection/incident response daha ileri bir aşamadır (gelecek geliştirme).

## Alternatives considered

- Refresh token localStorage: XSS riskini büyütür.
- Uzun ömürlü access token: çalınırsa etki alanı büyür.
- Stateful server-side session only: ölçek/dağıtım karmaşıklığı artar (yine de ileride değerlendirilebilir).

## Proof

- Local:
  - `.\ops\smoke.ps1` (refresh cookie + refresh/logout flow’u doğrular)
  - `.\ops\check.ps1` (opsiyonel refresh/logout check)
- Tests:
  - `services/api/test/refresh.test.js`


