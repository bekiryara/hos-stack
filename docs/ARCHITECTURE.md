# Architecture Overview

## H-OS vs Pazar

### H-OS (Host Operating System / Evren Hukuku)
H-OS is the central layer that provides:
- **Universal Rules**: Cross-world business rules and policies
- **Identity & Authorization**: Policy engine for access control
- **State Transitions**: Contract/FSM (Finite State Machine) for state management
- **Auditing**: Proof recorder for immutable audit logs

H-OS operates in three modes:
- **Embedded**: Rules run directly in Pazar (same process)
- **Hybrid**: Rules in Pazar, but contract validation via H-OS API
- **Remote**: Full separation, all rules/contracts via H-OS API

### Pazar (Ticaret Sahnesi)
Pazar is the commerce application ("world") that handles:
- Product catalog
- Orders and reservations
- Payments
- Commerce-specific business logic

Pazar integrates with H-OS for:
- Policy checks (authorization)
- Contract transitions (state management)
- Audit logging (proof recording)

## Services

### pazar-app (Port 8080)
- **Type**: Laravel (PHP 8.2) application
- **Purpose**: Main commerce application
- **Health Endpoint**: `/up` (HTTP 200)
- **Middleware**: RequestId, ForceJsonForApi, ErrorEnvelope
- **Features**: OIDC authentication, multi-tenant support, structured logging

### pazar-db (Port 5432)
- **Type**: PostgreSQL database
- **Purpose**: Pazar application data storage
- **Schema**: Managed via Laravel migrations, validated via `ops/schema_snapshot.ps1`

### hos-api (Port 3000)
- **Type**: Node.js (Fastify) application
- **Purpose**: H-OS API service (OIDC provider, policy engine, contract validation)
- **Health Endpoint**: `/v1/health` (expects `{"ok":true}`)
- **Features**: OIDC authorization server, policy evaluation, contract FSM

### hos-db (Port 5432)
- **Type**: PostgreSQL database
- **Purpose**: H-OS data storage (tenants, policies, contracts, proofs)

## Request Flows

### Health Check Flow
```
GET /up (Pazar)
  → Returns HTTP 200 (Laravel health endpoint)
  → X-Request-Id header included (if available)

GET /v1/health (H-OS)
  → Returns {"ok":true} JSON
```

### OIDC Authentication Flow
```
1. User → GET /auth/redirect (Pazar)
   → Redirects to H-OS /authorize with PKCE parameters
   
2. User → POST /authorize (H-OS)
   → Form submission with tenantSlug, email, password
   → H-OS validates and issues authorization code
   
3. Pazar → POST /token (H-OS)
   → Exchanges code for access token (PKCE verification)
   
4. Pazar → GET /userinfo (H-OS)
   → Retrieves user info with access token
   
5. Pazar → Creates/updates user session
   → Redirects to dashboard
```

### Pazar → H-OS API Calls (Remote/Hybrid Mode)
```
Pazar HTTP Client Request:
  → Includes X-Request-Id header (propagated from incoming request)
  → Includes X-HOS-API-KEY header (if configured)
  → POST/GET to H-OS endpoints

H-OS receives:
  → X-Request-Id for correlation
  → Validates API key (if required)
  → Processes policy/contract request
  → Returns response with X-Request-Id (if available)

Pazar logs:
  → Structured log with request_id in context
  → Outbox event payload includes request_id (optional)
```

## Contracts & Gates

### Route Contract (API Routes)
- **Snapshot**: `ops/snapshots/routes.pazar.json`
- **Validation**: `ops/routes_snapshot.ps1`
- **CI Gate**: `.github/workflows/contracts.yml`
- **Purpose**: Detect unintended route changes (new routes, renamed routes, removed routes)
- **Resolution**: If intentional, update snapshot; if unintentional, revert changes

### Schema Contract (Database Schema)
- **Snapshot**: `ops/snapshots/schema.pazar.sql`
- **Validation**: `ops/schema_snapshot.ps1`
- **CI Gate**: `.github/workflows/db-contracts.yml`
- **Purpose**: Detect unintended schema changes (migrations, column changes, index changes)
- **Resolution**: If intentional, update snapshot; if unintentional, revert migration

### Error Contract (Error Response Format)
- **Standard Envelope**: `{ ok:false, error_code, message, request_id, details? }`
- **Error Codes**: VALIDATION_ERROR, NOT_FOUND, UNAUTHORIZED, FORBIDDEN, INTERNAL_ERROR, HTTP_ERROR
- **CI Gate**: `.github/workflows/error-contract.yml`
- **Validation**: Ensures 422 and 404 responses use standard envelope with request_id
- **Implementation**: Global exception handler in `bootstrap/app.php`, ErrorEnvelope middleware

## Operational Entry Points

### ops/verify.ps1
- **Purpose**: Quick stack health verification
- **Checks**: Docker Compose services, H-OS health, Pazar up
- **Exit Code**: 0 on PASS, 1 on FAIL
- **Usage**: Run before/after deployments

### ops/triage.ps1
- **Purpose**: Incident triage and diagnostics
- **Checks**: Services, health endpoints, recent logs (120 lines), error patterns
- **Output**: Summary table with PASS/FAIL/WARN, log excerpts
- **Usage**: Run during incidents to identify service failures

### ops/conformance.ps1
- **Purpose**: Architecture conformance validation
- **Checks**: World registry drift, forbidden artifacts, disabled-world code, canonical docs, secrets safety
- **CI Gate**: `.github/workflows/conformance.yml`
- **Usage**: Validate architectural rules before merge

### ops/doctor.ps1
- **Purpose**: Comprehensive repository health check
- **Checks**: Services, health endpoints, tracked secrets, forbidden root artifacts, snapshot files
- **Output**: PASS/FAIL/WARN with next-step hints
- **Usage**: Pre-commit or pre-push validation

## Related Documentation

- [Repository Layout](./REPO_LAYOUT.md) - Repo structure contract
- [Rules](./RULES.md) - Development rules and standards
- [Incident Runbook](./runbooks/incident.md) - Incident response procedures
- [Observability Runbook](./runbooks/observability.md) - Request ID tracing
- [Errors Runbook](./runbooks/errors.md) - Error code reference

