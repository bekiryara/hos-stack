# WP-35: Docs DB Truth Lock - Proof Document

**Timestamp:** 2026-01-20  
**Status:** ✅ PASS

---

## Purpose

Fix documentation drift: Pazar DB engine description must match runtime truth (docker-compose.yml shows pazar-db uses PostgreSQL). Add a conformance guard to prevent reintroducing wrong DB references in docs.

---

## Changes Made

### 1. docs/index.md

**Before:**
```markdown
4. **Databases**
   - PostgreSQL (H-OS)
   - MySQL (Pazar)
```

**After:**
```markdown
4. **Databases**
   - PostgreSQL (H-OS)
   - PostgreSQL (Pazar)
```

**Also fixed Tech Stack section:**
- Before: `- **Database:** PostgreSQL, MySQL`
- After: `- **Database:** PostgreSQL`

### 2. docs/CODE_INDEX.md

**Before:**
```markdown
- `pazar-db` - MySQL database for Pazar
```

**After:**
```markdown
- `pazar-db` - PostgreSQL database for Pazar
```

### 3. ops/conformance.ps1

Added new section **F) Docs truth drift: DB engine alignment**:
- Reads docker-compose.yml to extract pazar-db image
- Detects DB engine (PostgreSQL if image contains "postgres", MySQL if contains "mysql" or "mariadb")
- Asserts docs/index.md contains expected DB label for Pazar (and does NOT contain opposite label)
- Asserts docs/CODE_INDEX.md contains "pazar-db - <expected DB label>"
- On mismatch: prints FAIL message and exits 1
- On success: prints PASS and continues

---

## Commands Run + Outputs

### 1. Conformance Check

```powershell
.\ops\conformance.ps1
```

**Output:**
```
=== Architecture Conformance Gate ===

[A] World registry drift check...
[FAIL] [A] World registry drift detected: Disabled in registry but not in config: messaging, social
  -> work\pazar\WORLD_REGISTRY.md
  -> work\pazar\config\worlds.php

[B] Forbidden artifacts check...
[PASS] [B] B - No forbidden artifacts (*.bak, *.tmp, *.orig, *.swp, *~)

[C] Disabled-world code policy check...
[PASS] [C] C - No code in disabled worlds (0 disabled)

[D] Canonical docs single-source check...
[PASS] [D] D - No duplicate CURRENT*.md or FOUNDING_SPEC*.md files (checked 1 unique files)

[E] Secrets safety check...
[PASS] [E] E - No secrets tracked in git

[F] Docs truth drift: DB engine alignment check...
[PASS] [F] F - Docs match docker-compose.yml: Pazar DB is PostgreSQL

[INFO] === Summary ===
[FAIL] CONFORMANCE FAILED

Failures:
  [A] World registry drift detected: Disabled in registry but not in config: messaging, social
    -> work\pazar\WORLD_REGISTRY.md
    -> work\pazar\config\worlds.php
```

**Exit Code:** 1 (due to pre-existing section A failure, not related to WP-35)

**Section F Status:** ✅ PASS - "Docs match docker-compose.yml: Pazar DB is PostgreSQL"

**Note:** Section A failure is a pre-existing issue unrelated to WP-35. Section F (the new guard) passed successfully.

### 2. Public Ready Check

```powershell
.\ops\public_ready_check.ps1
```

**Output:**
```
=== Public Ready Check ===

[1] Git working tree check...
[PASS] Git working tree is clean (no uncommitted changes)

[2] Secret scan check...
[PASS] Secret scan passed (0 hits)

[3] .env files check...
[PASS] No .env files tracked in git

[4] Vendor/node_modules check...
[PASS] No vendor/ or node_modules/ tracked in git

[INFO] === Summary ===
[PASS] PUBLIC READY CHECK PASSED
```

**Exit Code:** 0 ✅

---

## Verification

### Docker Compose Truth

From `docker-compose.yml`:
```yaml
  pazar-db:
    image: postgres:16-alpine
```

**Confirmed:** pazar-db uses PostgreSQL 16.

### Documentation Alignment

✅ `docs/index.md` now correctly states "PostgreSQL (Pazar)"  
✅ `docs/CODE_INDEX.md` now correctly states "pazar-db - PostgreSQL database for Pazar"  
✅ Conformance guard (section F) validates this alignment automatically

---

## Files Changed

1. `docs/index.md` - Fixed Pazar DB description from MySQL to PostgreSQL
2. `docs/CODE_INDEX.md` - Fixed pazar-db description from MySQL to PostgreSQL
3. `ops/conformance.ps1` - Added section F: Docs truth drift: DB engine alignment
4. `docs/PROOFS/wp35_docs_db_truth_lock_pass.md` - This proof document
5. `docs/WP_CLOSEOUTS.md` - Updated with WP-35 entry

---

## Exit Codes

- `.\ops\conformance.ps1`: Exit code 1 (due to pre-existing section A failure, not WP-35)
- `.\ops\public_ready_check.ps1`: Exit code 0 ✅

**Section F (new guard):** ✅ PASS - No FAIL strings in section F output.

---

**Proof Complete:** WP-35 successfully fixes doc drift and adds conformance guard to prevent future drift.

