# BASELINE Release Plan

**Baseline Tag:** `BASELINE-2026-01-14`  
**Date:** 2026-01-14  
**Baseline Definition:** RELEASE-GRADE BASELINE RESET v1

## What is BASELINE?

The BASELINE is the minimum working state that must be maintained. It represents:
- A stable, reproducible state
- Core services running and healthy
- Health checks passing
- No breaking changes to infrastructure

## What is Guaranteed

When you checkout the BASELINE tag, you are guaranteed:

1. **Core Services Start Successfully**
   - `hos-db`, `hos-api`, `hos-web` (H-OS core)
   - `pazar-db`, `pazar-app` (Pazar core)

2. **Health Checks Pass**
   - H-OS: `GET http://localhost:3000/v1/health` returns `{"ok":true}`
   - Pazar: `GET http://localhost:8080/up` returns `"ok"`

3. **Verification Scripts Pass**
   - `.\ops\verify.ps1` returns exit code 0
   - `.\ops\baseline_status.ps1` returns exit code 0

4. **Documentation is Complete**
   - `docs/CURRENT.md` describes the stack
   - `docs/ONBOARDING.md` provides quick start
   - `docs/DECISIONS.md` documents frozen items

## What is NOT Guaranteed

- Application features may be minimal (GENESIS state)
- Database may be empty (no seed data)
- Optional services (observability) may not be included
- Performance characteristics are not defined

## Creating the BASELINE Tag

```powershell
# Ensure baseline passes
.\ops\verify.ps1

# Create tag
git tag -a BASELINE-2026-01-14 -m "BASELINE: RELEASE-GRADE BASELINE RESET v1"

# Push tag (optional)
git push origin BASELINE-2026-01-14
```

## Checking Out the BASELINE

```powershell
# Checkout baseline tag
git checkout BASELINE-2026-01-14

# Start stack
docker compose up -d --build

# Verify baseline
.\ops\verify.ps1
```

## Related Documentation

- **Proof:** `docs/PROOFS/baseline_pass.md` (verification evidence)
- **Current State:** `docs/CURRENT.md` (single source of truth)
- **Decisions:** `docs/DECISIONS.md` (frozen items)






