# Incident Response Runbook

## Severity Definitions

### SEV1 - Critical (Page On-Call)
- **System down**: Entire application unavailable
- **Data loss**: Actual or potential data corruption/loss
- **Security breach**: Active attack or confirmed vulnerability exploit
- **Response time**: Immediate (within 15 minutes)
- **Resolution target**: 1 hour

### SEV2 - High (Escalate)
- **Major functionality broken**: Core feature unavailable, workaround exists
- **Performance degradation**: >50% response time increase, affects >10% users
- **Partial outage**: Single service down but system partially functional
- **Response time**: Within 1 hour
- **Resolution target**: 4 hours

### SEV3 - Medium (Normal Queue)
- **Minor functionality broken**: Non-critical feature unavailable, workaround exists
- **Performance issues**: Moderate impact, affects <10% users
- **Intermittent errors**: Sporadic failures with workaround
- **Response time**: Within 4 hours
- **Resolution target**: Next business day

## 10-Minute Triage Checklist

1. **Reproduce the issue** (2 min)
   - Can you reproduce it consistently?
   - Is it user-specific or system-wide?
   - What actions lead to the error?

2. **Check system health** (1 min)
   ```powershell
   .\ops\triage.ps1
   ```
   - Are all services up?
   - Are health endpoints responding?

3. **Capture request_id** (2 min)
   - If error response is available, note the `request_id` field
   - If reproducing via browser/API client, check response headers for `X-Request-Id`
   - If no request_id in response, check if it's a non-JSON error or pre-middleware failure

4. **Search logs** (3 min)
   ```powershell
   # Search by request_id
   docker compose logs pazar-app | Select-String "request_id.*<uuid>"
   docker compose logs hos-api | Select-String "request_id.*<uuid>"
   
   # Search by error_code (if available)
   docker compose logs pazar-app | Select-String "error_code.*VALIDATION_ERROR"
   ```
   - Use `request_id` to trace the full request flow
   - Check both `pazar-app` and `hos-api` logs
   - Look for error patterns, stack traces, or exception messages

5. **Identify service** (1 min)
   - Is it Pazar-specific? (check `pazar-app` logs)
   - Is it H-OS related? (check `hos-api` logs)
   - Is it infrastructure? (check `docker compose ps`, network, volumes)

6. **Document findings** (1 min)
   - SEV level assignment
   - Affected service(s)
   - request_id(s) for tracking
   - Error pattern or message
   - Next steps or escalation decision

## Request ID Workflow

### Step 1: Reproduce and Capture
When an error occurs:
1. Note the error response JSON (if available)
2. Extract `request_id` from the response body: `{ "ok": false, "error_code": "...", "request_id": "uuid-here", ... }`
3. Alternatively, check response headers: `X-Request-Id: uuid-here`

### Step 2: Search Logs
```powershell
# Search Pazar logs by request_id
docker compose logs --tail 500 pazar-app | Select-String "request_id.*<uuid>" -Context 10

# Search H-OS logs by request_id
docker compose logs --tail 500 hos-api | Select-String "request_id.*<uuid>" -Context 10

# Search by error_code and request_id together
docker compose logs pazar-app | Select-String "error_code.*VALIDATION_ERROR" -Context 5 | Select-String "request_id"
```

### Step 3: Isolate Service
- **If found in pazar-app logs**: Issue is in Pazar application code or middleware
- **If found in hos-api logs**: Issue is in H-OS API (remote mode) or H-OS service call
- **If found in both**: Trace the flow to see where the error originated (check timestamps)

### Step 4: Deep Dive
Once service is identified:
1. Check full log context around the request_id match
2. Look for stack traces or exception details
3. Check related service logs if it's a multi-service flow (e.g., Pazar → H-OS)
4. Use `request_id` to trace the complete request lifecycle

## CI Gate Failure Troubleshooting

If a CI gate fails in GitHub Actions, check these locations:

### repo-guard
- **What it checks**: Root artifacts (zip, rar, 7z, tar.gz), tracked logs, tracked secrets
- **Where to look**: `.github/workflows/repo-guard.yml` logs
- **Common causes**: Accidental commit of log files, secrets, or archive files in root
- **Fix**: Remove offending files, update `.gitignore` if needed

### smoke
- **What it checks**: Docker Compose stack health, `/v1/health`, `/up` endpoints
- **Where to look**: `.github/workflows/smoke.yml` logs, `docker compose ps` output
- **Common causes**: Service startup failure, health check timeout, port conflicts
- **Fix**: Check service logs, ensure ports are available, verify Docker Compose config

### conformance
- **What it checks**: World registry drift, forbidden artifacts, disabled-world code, canonical docs, secrets safety
- **Where to look**: `.github/workflows/conformance.yml` logs, `ops/conformance.ps1` output
- **Common causes**: World registry mismatch, disabled world code present, docs not single-source
- **Fix**: Run `.\ops\conformance.ps1` locally to see detailed failure reasons

### contracts (routes)
- **What it checks**: API routes match snapshot
- **Where to look**: `.github/workflows/contracts.yml` logs, `ops/diffs/routes.diff`
- **Common causes**: New routes added, routes renamed, routes removed
- **Fix**: If intentional, update `ops/snapshots/routes.pazar.json`; if unintentional, revert route changes

### db-contracts (schema)
- **What it checks**: Database schema matches snapshot
- **Where to look**: `.github/workflows/db-contracts.yml` logs, `ops/diffs/schema.diff`
- **Common causes**: Migration added/removed, column changes, index changes
- **Fix**: If intentional, update `ops/snapshots/schema.pazar.sql`; if unintentional, revert migration

### error-contract
- **What it checks**: Error envelope format (422 validation, 404 not found)
- **Where to look**: `.github/workflows/error-contract.yml` logs, response body format
- **Common causes**: Error response format changed, request_id missing, error_code format changed
- **Fix**: Ensure error responses use standard envelope format (see `docs/runbooks/errors.md`)

## Safe Rollback Notes

### Before Rolling Back
1. **Identify the commit**: Use `git log` or CI/CD logs to find the breaking commit
2. **Check snapshots**: Review `ops/snapshots/` to understand what changed
3. **Check gates**: Review which gates failed and why (see CI Gate Failure Troubleshooting above)

### Rollback Procedure
```powershell
# 1. Identify current commit
git log --oneline -1

# 2. Find last known good commit (before the breaking change)
git log --oneline -10

# 3. Create a backup branch (optional, for investigation later)
git branch backup-before-rollback

# 4. Revert to last known good commit
git reset --hard <commit-hash>

# 5. Force push (if necessary, coordinate with team)
git push --force-with-lease origin main
```

### Prevention Discipline
- **Always**: Test locally with `.\ops\verify.ps1` before pushing
- **Always**: Run `.\ops\triage.ps1` after any deployment to verify health
- **Always**: Update snapshots (`routes.pazar.json`, `schema.pazar.sql`) when intentionally changing contracts
- **Never**: Skip gate checks or disable gates without team discussion
- **Never**: Force push to main without coordinating with team

## Quick Reference

### Health Endpoints
- H-OS Health: `http://localhost:3000/v1/health`
- Pazar Up: `http://localhost:8080/up`

### Key Scripts
- Triage: `.\ops\triage.ps1`
- Verify: `.\ops\verify.ps1`
- Conformance: `.\ops\conformance.ps1`

### Log Locations
- Pazar logs: `docker compose logs pazar-app`
- H-OS logs: `docker compose logs hos-api`
- All logs: `docker compose logs --tail 100`

### Related Runbooks
- [Observability Runbook](./observability.md) - Using request_id for tracing
- [Errors Runbook](./errors.md) - Error code reference and handling

