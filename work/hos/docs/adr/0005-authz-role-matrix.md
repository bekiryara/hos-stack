# 0005 — AuthZ Role Matrix (Owner/Admin/Member)

- Status: accepted
- Date: 2025-12-26
- Owner: TBD

## Context

Multi-tenant bir platform çekirdeğinde “auth var” yeterli değildir; her endpoint için **kim ne yapabilir** açık olmalıdır.
Bu açıklık hem güvenliği hem de ekip hafızasını güçlendirir.

## Decision

H-OS’ta 3 rol vardır: `member`, `admin`, `owner`.

Minimal policy matrisi (v1):
- **Public**:
  - `GET /v1/health`, `GET /v1/ready`, `GET /metrics`, `GET /v1/meta/features`
- **Authenticated (any role)**:
  - `GET /v1/me`
- **Elevated (admin or owner)**:
  - `GET /v1/users`
  - `GET /v1/audit`
- **Owner only**:
  - `PATCH /v1/users/:id/role`

## Consequences

### Positive

- Tenant içi yetki ihlali riskini azaltır.
- Testlerle kanıtlanabilir ve değişiklikler PR’da yakalanır.

### Negative / Risks

- Politika zamanla büyür; doküman/test bakımı gerekir.

## Proof

- Local:
  - `cd services/api && npm test`
- Tests:
  - `services/api/test/rbac.test.js`
  - `services/api/test/authz.test.js`
  - `services/api/test/role_matrix.test.js`


