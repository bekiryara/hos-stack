# OpenAPI Contract Runbook

**Purpose**: Validates OpenAPI specification exists, is valid, and matches implemented endpoints. Prevents contract drift.

**Script**: `ops/openapi_contract.ps1`

## What It Checks

1. **File Exists**: Validates `docs/product/openapi.yaml` exists
2. **YAML Structure**: Validates OpenAPI spec contains required fields:
   - `openapi:` field (OpenAPI version)
   - `paths:` field (API endpoints)
   - `components:` field (shared schemas)
   - `ErrorEnvelope` schema definition
   - `request_id` field in ErrorEnvelope
3. **Documentation Drift Guard**: Checks that `docs/product/PRODUCT_API_SPINE.md` references `openapi.yaml` as single source of truth
4. **Optional Endpoint Probe**: If Docker stack is reachable, validates that unauthorized endpoint returns 401/403 with `request_id` in body (matches documented error envelope)

## How to Run

### Local (Interactive)

```powershell
.\ops\openapi_contract.ps1
```

### With Custom Base URL

```powershell
.\ops\openapi_contract.ps1 -BaseUrl "http://localhost:8080"
```

### CI (Automated)

The gate runs automatically on:
- Pull requests to `main` or `develop`
- Pushes to `main` or `develop`
- When OpenAPI spec or related files change

See `.github/workflows/openapi-contract.yml` for CI configuration.

## Expected Output

### PASS

```
=== OPENAPI CONTRACT CHECK ===
Timestamp: 2026-01-11 12:00:00

Check 1: OpenAPI spec file exists
  [PASS] File exists - OpenAPI spec file found: docs\product\openapi.yaml

Check 2: YAML structure validation
  [PASS] YAML structure (openapi field) - Contains 'openapi:' field
  [PASS] YAML structure (paths field) - Contains 'paths:' field
  [PASS] YAML structure (components field) - Contains 'components:' field
  [PASS] YAML structure (ErrorEnvelope schema) - Contains ErrorEnvelope schema
  [PASS] YAML structure (request_id field) - Contains request_id field

Check 3: Documentation drift guard
  [PASS] Documentation drift guard - PRODUCT_API_SPINE.md references OpenAPI spec

Check 4: Endpoint probe (optional)
  [PASS] Endpoint probe (unauthorized response) - Unauthorized endpoint returns 401/403 with request_id in body

=== OPENAPI CONTRACT CHECK RESULTS ===

Check                                    Status Notes
-----                                    ------ -----
File exists                              PASS   OpenAPI spec file found: docs\product\openapi.yaml
YAML structure (openapi field)          PASS   Contains 'openapi:' field
YAML structure (paths field)            PASS   Contains 'paths:' field
YAML structure (components field)       PASS   Contains 'components:' field
YAML structure (ErrorEnvelope schema)   PASS   Contains ErrorEnvelope schema
YAML structure (request_id field)       PASS   Contains request_id field
Documentation drift guard                PASS   PRODUCT_API_SPINE.md references OpenAPI spec
Endpoint probe (unauthorized response)   PASS   Unauthorized endpoint returns 401/403 with request_id in body

OVERALL STATUS: PASS
```

### WARN (Optional Checks Skipped)

```
Check 4: Endpoint probe (optional)
  [WARN] Endpoint probe (stack reachable) - Docker stack not reachable at http://localhost:8080, skipping endpoint probe

OVERALL STATUS: WARN
```

### FAIL (Missing/Invalid Contract)

```
Check 1: OpenAPI spec file exists
  [FAIL] File exists - OpenAPI spec file not found: docs\product\openapi.yaml

OVERALL STATUS: FAIL
```

## How to Update openapi.yaml Safely

1. **Edit the spec**: Update `docs/product/openapi.yaml` with new endpoints or changes
2. **Validate locally**: Run `.\ops\openapi_contract.ps1` to check for syntax errors
3. **Verify endpoints match**: Ensure documented endpoints match actual implementation in `work/pazar/routes/api.php`
4. **Update PRODUCT_API_SPINE.md**: Add reference to `openapi.yaml` if not already present
5. **Commit and push**: CI will automatically validate the contract

## What Breaks the Gate

- **Missing file**: `docs/product/openapi.yaml` does not exist → FAIL
- **Invalid YAML**: Missing required fields (`openapi:`, `paths:`, `components:`) → FAIL
- **Missing ErrorEnvelope**: ErrorEnvelope schema not defined → FAIL
- **Missing request_id**: `request_id` field not in ErrorEnvelope → FAIL
- **Documentation drift**: PRODUCT_API_SPINE.md doesn't reference openapi.yaml → WARN (non-blocking)

## How to Verify Locally

1. **Check file exists**:
   ```powershell
   Test-Path docs\product\openapi.yaml
   ```

2. **Validate YAML syntax** (if you have yq or similar):
   ```powershell
   # Using yq (if installed)
   yq eval '.' docs\product\openapi.yaml
   ```

3. **Run contract check**:
   ```powershell
   .\ops\openapi_contract.ps1
   ```

4. **Check endpoint matches** (if stack is up):
   ```powershell
   curl.exe -i -X GET http://localhost:8080/api/v1/commerce/listings
   # Should return 401/403 with JSON envelope containing request_id
   ```

## Troubleshooting

### File Not Found

**Symptom**: FAIL status, "OpenAPI spec file not found"

**Solution**: Ensure `docs/product/openapi.yaml` exists. Create it if missing.

### Missing Required Fields

**Symptom**: FAIL status, "Missing 'openapi:' field" (or similar)

**Solution**: Ensure OpenAPI spec contains:
- `openapi: 3.1.0` (or 3.0.0)
- `paths:` section with endpoint definitions
- `components:` section with ErrorEnvelope schema

### Documentation Drift

**Symptom**: WARN status, "PRODUCT_API_SPINE.md should reference openapi.yaml"

**Solution**: Add reference to `openapi.yaml` in `docs/product/PRODUCT_API_SPINE.md`:
```markdown
## OpenAPI Specification

The canonical API contract is defined in [openapi.yaml](openapi.yaml).
```

### Endpoint Probe Fails

**Symptom**: WARN status, "Docker stack not reachable"

**Solution**: This is expected if Docker stack is not running. Start the stack with `docker compose up` if you want to enable endpoint probe validation.

## Related Documentation

- `docs/product/openapi.yaml` - OpenAPI specification (single source of truth)
- `docs/product/PRODUCT_API_SPINE.md` - Product API documentation (should reference openapi.yaml)
- `docs/PROOFS/openapi_contract_pass.md` - Acceptance tests

## Incident Response

If OpenAPI Contract Check fails in CI:
1. Check PR description for OpenAPI spec changes
2. Verify `docs/product/openapi.yaml` exists and is valid YAML
3. Ensure required fields are present (openapi, paths, components, ErrorEnvelope)
4. Run `.\ops\openapi_contract.ps1` locally to reproduce
5. Fix issues and re-run CI check





