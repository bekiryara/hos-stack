# Pazar Build Context Fix + Conformance Null-Safe Patch v1

## Implementation Summary

### Changes Made

**1. Docker Compose Build Context (Already Correct)**
- `docker-compose.yml` already has correct build context: `./work/pazar` for both `pazar-app` and `pazar-perms-init`
- Dockerfile path: `docker/Dockerfile` (relative to context root)
- No changes needed to compose file

**2. Dockerfile (Already Fixed)**
- `work/pazar/docker/Dockerfile` already uses `COPY composer.lock* ./` (optional)
- All COPY paths are relative to context root: `docker/nginx/default.conf`, `docker/supervisord.conf`, etc.
- No changes needed

**3. Required Files (All Present)**
- `work/pazar/composer.json` - EXISTS
- `work/pazar/composer.lock` - EXISTS
- `work/pazar/docker/nginx/default.conf` - EXISTS
- `work/pazar/docker/supervisord.conf` - EXISTS
- `work/pazar/docker/docker-entrypoint.sh` - EXISTS

**4. Conformance Script Null-Safe Fixes**
- **World registry drift check**: Added null-safe array initialization and comparison
  - Ensures `$registryEnabled` and `$registryDisabled` are never null before Compare-Object
  - Handles empty file content gracefully
  - Validates `Get-WorldsConfig` return value before use
- **Canonical docs duplicate detection**: Fixed to only fail when actual duplicates exist (>1 unique path per filename)
  - Groups files by normalized filename (case-insensitive)
  - Only reports duplicates when a group has >1 unique full path
  - Single file per name = PASS

### Files Modified

1. `ops/conformance.ps1`
   - Lines 77-131: Added null-safe parsing for WORLD_REGISTRY.md
   - Lines 133-143: Added null checks before Compare-Object calls
   - Lines 264-310: Fixed canonical docs duplicate detection logic

### Verification Commands

```powershell
# 1) Build and start pazar
docker compose up -d --build pazar-db pazar-app

# Expected: Build succeeds; pazar-app container is Up

# 2) Verify pazar /up
curl.exe -i http://localhost:8080/up

# Expected: HTTP 200

# 3) Verify stack
.\ops\verify.ps1

# Expected:
# - H-OS health PASS (already OK)
# - Pazar health PASS (not SKIP)
# - Pazar FS posture PASS (no "service pazar-app is not running")

# 4) Conformance
.\ops\conformance.ps1

# Expected:
# - No null-binding error
# - If world registry truly differs, it should FAIL with clear diff; otherwise PASS
# - Canonical docs check should only FAIL if actual duplicates exist (>1 unique path per filename)
```

### Why These Changes

- **Build context**: Already correct (`./work/pazar`), no changes needed
- **Dockerfile**: Already uses optional `composer.lock*`, no changes needed
- **Conformance null-safety**: Prevents "Cannot bind argument to parameter 'ReferenceObject' because it is null" errors
- **Duplicate detection**: Only fails on actual duplicates (>1 unique path), not single files

### Minimal Diff Principle

- Only modified `ops/conformance.ps1` for null-safety and duplicate detection logic
- No changes to Docker compose or Dockerfile (already correct)
- No refactoring, only correctness fixes











