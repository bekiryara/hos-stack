# WP Closeouts - Workspace Package Summaries

**Last Updated:** 2026-01-22  
**Purpose:** Short summaries of completed Workspace Packages (WP) with deliverables, commands, and proof evidence.

**Archive:** Older WP entries have been moved to archive files to keep this index small:
- [docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026.md](closeouts/WP_CLOSEOUTS_ARCHIVE_2026.md)
- [docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026_B.md](closeouts/WP_CLOSEOUTS_ARCHIVE_2026_B.md)

Only the last 8 WP entries are shown here.

---
---

## WP-51: User-Like Prototype Demo Entrypoint

**Purpose:** Turn the now-GREEN E2E backend flow (WP-48) into a user-like, repeatable prototype demo you can run + click through. Single command prepares demo data, prints clickable URLs, and provides a deterministic checklist.

**Deliverables:**
- ops/prototype_user_demo.ps1 (NEW): Single entrypoint for user-like demo (optional Docker stack start, waits for services, runs ensure_demo_membership + prototype_flow_smoke + frontend_smoke, extracts artifacts, prints click targets + checklist, optional browser open)
- ops/prototype_flow_smoke.ps1 (MODIFIED): Added RESULT line on PASS with tenant_id, listing_id, thread_id for demo orchestration
- docs/PROOFS/wp51_user_demo_pass.md (NEW): Proof document

**Commands:**
```powershell
# Run user demo (prepares data + prints URLs + checklist)
.\ops\prototype_user_demo.ps1

# Optional: Start Docker stack first
.\ops\prototype_user_demo.ps1 -StartStack

# Optional: Open browser automatically
.\ops\prototype_user_demo.ps1 -OpenBrowser

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** 
- docs/PROOFS/wp51_user_demo_pass.md

**Acceptance:**
- prototype_user_demo: PASS (all scripts PASS, click targets printed, checklist provided)
- prototype_flow_smoke: PASS (RESULT line printed)
- frontend_smoke: PASS
- All gates: PASS

---

## WP-49: Demo Membership Bootstrap (Make prototype_flow_smoke GREEN)

**Purpose:** Make Prototype v1 "user-like" E2E flow deterministic by ensuring the test user always has a valid tenant membership. prototype_flow_smoke can now run without manual setup.

**Deliverables:**
- work/hos/services/api/src/app.js (MODIFIED): Added `POST /v1/admin/memberships/upsert` admin endpoint (DEV/OPS bootstrap only, requires x-hos-api-key, creates/updates membership linking user to tenant)
- ops/ensure_demo_membership.ps1 (NEW): Bootstrap script that guarantees test user has membership with valid tenant UUID (acquires JWT, checks memberships, bootstraps if needed, verifies)
- ops/prototype_flow_smoke.ps1 (MODIFIED): Automatically calls bootstrap if tenant_id is missing (retries memberships after bootstrap)
- ops/ensure_demo_membership.ps1 (MODIFIED): Fixed UUID validation in Get-TenantIdFromMemberships helper (uses [System.Guid]::Empty instead of null)
- docs/PROOFS/wp49_demo_membership_bootstrap_pass.md (NEW): Proof document

**Commands:**
```powershell
# Run bootstrap
.\ops\ensure_demo_membership.ps1

# Run smoke tests
.\ops\prototype_smoke.ps1
.\ops\frontend_smoke.ps1
.\ops\prototype_flow_smoke.ps1

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** 
- docs/PROOFS/wp49_demo_membership_bootstrap_pass.md

**Acceptance:**
- ensure_demo_membership: PASS (membership bootstrap working, tenant_id extracted)
- prototype_flow_smoke: PASS (tenant_id acquired successfully, bootstrap integration working)
- prototype_smoke: PASS
- frontend_smoke: PASS
- All gates: PASS

**Notes:**
- **Minimal diff:** Only admin endpoint addition and bootstrap script
- **No refactor:** Reuses existing test_auth.ps1 helper
- **Security:** Admin endpoint requires x-hos-api-key, tokens masked
- **Idempotent:** Bootstrap safe to run multiple times

---

## WP-48: Prototype Green Pack v1 (Frontend Marker Alignment + Memberships tenant_id Fix + persona.scope Middleware Fix)

**Purpose:** Make Prototype v1 deterministically GREEN by fixing frontend_smoke/prototype_smoke marker inconsistency, making prototype_flow_smoke tenant_id extraction robust, and fixing Laravel terminate phase persona.scope middleware alias resolution issue.

**Deliverables:**
- ops/frontend_smoke.ps1 (MODIFIED): Marker check aligned with prototype_smoke.ps1 (checks for HTML comment OR data-test OR heading text), prints body preview on FAIL
- ops/prototype_flow_smoke.ps1 (MODIFIED): Added Get-TenantIdFromMemberships helper function (handles multiple response formats, iterates all memberships, tries multiple field paths, validates UUID), enhanced error messages with schema hints
- work/pazar/routes/api/*.php (MODIFIED): Replaced middleware alias 'persona.scope:guest/store/personal' with full class name \App\Http\Middleware\PersonaScope::class . ':guest/store/personal' in all route files (fixes Laravel terminate phase "Target class [persona.scope] does not exist" error)
- docs/PROOFS/wp48_frontend_marker_alignment_pass.md (UPDATED): Proof document with latest test results
- docs/PROOFS/wp48_prototype_flow_memberships_fix_pass.md (UPDATED): Proof document with full end-to-end PASS results

**Commands:**
```powershell
# Run smoke tests
.\ops\prototype_smoke.ps1
.\ops\frontend_smoke.ps1
.\ops\prototype_flow_smoke.ps1

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** 
- docs/PROOFS/wp48_frontend_marker_alignment_pass.md
- docs/PROOFS/wp48_prototype_flow_memberships_fix_pass.md

**Acceptance:**
- frontend_smoke: PASS (marker aligned, consistent with prototype_smoke)
- prototype_smoke: PASS (marker check unchanged)
- prototype_flow_smoke: PASS (full end-to-end: JWT → tenant_id → listing creation → listing publish → messaging thread → message posting)
- All gates: PASS

**Notes:**
- **Minimal diff:** Only marker check alignment, tenant_id extraction helper, and middleware alias fix
- **No refactor:** No business logic changes
- **ASCII-only:** All outputs ASCII format
- **PowerShell 5.1:** Compatible
- **persona.scope fix:** Resolves Laravel Kernel terminate phase alias resolution issue by using full class names

---

## WP-47: Dev Auth Determinism (JWT Bootstrap Must Pass)

**Purpose:** Make prototype_flow_smoke JWT bootstrap deterministically PASS with proper error handling. Fix response body reading, improve error messages, fix email format.

**Deliverables:**
- ops/_lib/test_auth.ps1 (MODIFIED): Improved response body reading (ErrorDetails.Message first, then GetResponseStream), enhanced error parsing (handles Zod error format), better 401 error messages, email format fixed (testuser@example.com)
- ops/prototype_flow_smoke.ps1 (MODIFIED): Explicit API key handling, better error messages, token masking
- docs/PROOFS/wp47_dev_auth_determinism_pass.md (NEW): Proof document

**Commands:**
```powershell
# Run prototype flow smoke
.\ops\prototype_flow_smoke.ps1

# Run prototype v1 runner
.\ops\prototype_v1.ps1
```

**Proof:** docs/PROOFS/wp47_dev_auth_determinism_pass.md

**Acceptance:**
- JWT token acquisition: PASS (token obtained successfully)
- Error handling: Improved (response body parsed, fieldErrors displayed)
- API key handling: Improved (env variable support, clear 401 messages)
- Token masking: PASS (last 6 chars only)

**Notes:**
- **Minimal diff:** Only error handling improvements, email format fix
- **No refactor:** No business logic changes
- **ASCII-only:** All outputs ASCII format
- **PowerShell 5.1:** Compatible

---

## WP-38: Pazar Ping Reliability v1

**Purpose:** Fix marketplace ping false-OFFLINE issue by increasing timeout, consolidating ping logic into shared helper, and using Docker network-friendly defaults.

**Deliverables:**
- `work/hos/services/api/src/app.js` - Shared `pingWorldAvailability()` helper, timeout 500ms→2000ms, parallel ping execution
- `docker-compose.yml` - Added `WORLD_PING_TIMEOUT_MS: "2000"`
- `ops/world_status_check.ps1` - Enhanced debug messages (timeout + endpoint info)
- `docs/PROOFS/wp38_pazar_ping_reliability_pass.md` - Proof document

**Commands:**
```powershell
docker compose build hos-api
docker compose up -d hos-api
.\ops\world_status_check.ps1  # Must PASS
Invoke-WebRequest http://localhost:3000/v1/worlds  # marketplace must be ONLINE
```

**Proof:** `docs/PROOFS/wp38_pazar_ping_reliability_pass.md`

**Acceptance:**
- ✅ Marketplace ping returns ONLINE (was OFFLINE before)
- ✅ Timeout increased to 2000ms (configurable via WORLD_PING_TIMEOUT_MS)
- ✅ Code duplication eliminated (shared helper for marketplace + messaging)
- ✅ Parallel ping execution (Promise.all) for latency optimization
- ✅ Docker network default URLs (pazar-app:80, messaging-api:3000)
- ✅ Ops test PASS (all availability rules satisfied)

**Notes:**
- **Minimal diff:** Only ping logic refactored, no other changes
- **No duplication:** Single helper replaces 80+ lines of duplicated code
- **Timeout configurable:** WORLD_PING_TIMEOUT_MS env var (default: 2000ms)
- **Retry logic:** 1 retry on timeout/AbortError
- **JSON shape preserved:** /v1/worlds response format unchanged
- **ASCII-only:** All outputs ASCII format

---


## WP-39: Closeouts Rollover v1 (Index + Archive)

**Purpose:** Reduce docs/WP_CLOSEOUTS.md file size by keeping only the last 12 WP entries in the main file and moving older entries to an archive file.

**Deliverables:**
- docs/WP_CLOSEOUTS.md (MOD): Reduced to last 12 WP entries (WP-27 to WP-38), added archive link
- docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026.md (NEW): Archive file containing older WP entries
- docs/CODE_INDEX.md (MOD): Added archive link entry
- docs/PROOFS/wp39_closeouts_rollover_pass.md - Proof document

**Commands:**
`powershell
# Check line counts
(Get-Content docs\WP_CLOSEOUTS.md | Measure-Object -Line).Lines
(Get-Content docs\closeouts\WP_CLOSEOUTS_ARCHIVE_2026.md | Measure-Object -Line).Lines

# Validate gates
.\ops\conformance.ps1
.\ops\public_ready_check.ps1
.\ops\secret_scan.ps1
`

**Proof:** docs/PROOFS/wp39_closeouts_rollover_pass.md

**Acceptance:**
-  WP_CLOSEOUTS.md reduced from 2022 lines to ~1100 lines (last 12 WP only)
-  Archive file created with older WP entries
-  Archive link added to main file header
-  CODE_INDEX.md updated with archive link
-  All governance gates PASS (conformance, public_ready_check, secret_scan)

**Notes:**
- **No behavior change:** Docs-only change, no code modifications
- **Minimal diff:** Only documentation files modified
- **Link stability:** Archive link uses relative path, stable across environments
- **Content preservation:** All WP entries moved verbatim, no rewriting
- **ASCII-only:** All outputs ASCII format

---

## WP-42: GitHub Sync Safe Windows Compatibility (pwsh fallback + syntax fix)

**Purpose:** Remove pwsh dependency from github_sync_safe.ps1 to make it runnable on Windows PowerShell 5.1 (pwsh optional).

**Deliverables:**
- ops/github_sync_safe.ps1 (MODIFIED): Removed `#!/usr/bin/env pwsh` shebang, added `Get-PowerShellExe` helper (checks for pwsh, falls back to powershell.exe), replaced all `& pwsh` invocations with `& $PowerShellExe`, fixed pre-existing syntax errors
- docs/PROOFS/wp42_github_sync_safe_windows_pass.md - Proof document

**Commands:**
```powershell
# Syntax check
powershell -NoProfile -Command "$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile('ops/github_sync_safe.ps1',[ref]$t,[ref]$e) | Out-Null; $e.Count"
# Expected: 0 (no syntax errors)

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
.\ops\github_sync_safe.ps1
```

**Proof:** docs/PROOFS/wp42_github_sync_safe_windows_pass.md

**Acceptance:**
- ✅ pwsh dependency removed (script works on Windows PowerShell 5.1)
- ✅ Syntax errors fixed (PowerShell parser confirms 0 errors)
- ✅ All gates PASS (secret_scan, public_ready_check, conformance, github_sync_safe)
- ✅ Script runs without crash (exits early if not on default branch, expected behavior)

**Notes:**
- **Minimal diff:** Only pwsh fallback + syntax fixes, no refactor
- **Windows compatible:** Works on PowerShell 5.1 without pwsh requirement
- **ASCII-only:** All outputs ASCII format

---

## WP-41: Gates Restore (secret scan + conformance parser)

**Purpose:** Restore WP-33-required gates (secret_scan.ps1), fix conformance false FAIL by making worlds_config.ps1 parse multiline PHP arrays, and track canonical files.

**Deliverables:**
- ops/secret_scan.ps1 (NEW): Scans tracked files for common secret patterns, skips binaries and allowlisted placeholders, ASCII-only output
- ops/_lib/worlds_config.ps1 (FIX): Updated regex to handle multiline PHP arrays using `(?s)` Singleline option
- ops/conformance.ps1 (FIX): Updated registry parser to use `(?s)` for multiline matching and `"`r?`n"` for line splitting
- docs/MERGE_RECOVERY_PLAN.md (TRACKED): Added to git tracking
- ops/_lib/test_auth.ps1 (TRACKED): Added to git tracking
- docs/PROOFS/wp41_gates_restore_pass.md - Proof document

**Commands:**
```powershell
# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** docs/PROOFS/wp41_gates_restore_pass.md

**Acceptance:**
- ✅ Secret scan: 0 hits (PASS)
- ✅ Conformance: All checks PASS (world registry drift fixed, multiline parser working)
- ✅ Public ready: PASS after commit (canonical files tracked)
- ✅ All gates PASS

**Notes:**
- **Minimal diff:** Only gate restoration + parser fixes, no feature work
- **No refactor:** Only fixes needed to pass gates
- **ASCII-only:** All outputs ASCII format

---

## WP-44: Prototype Spine v1 (Runtime Smoke + Prototype Launcher + Deterministic Output)

**Purpose:** Add definitive runtime smoke script and Prototype Launcher UI section. Make frontend_smoke.ps1 output deterministic (no silent/blank runs).

**Deliverables:**
- ops/prototype_smoke.ps1 (NEW): Runtime smoke script (Docker services + HTTP endpoints + HOS Web UI marker)
- work/hos/services/web/src/ui/App.tsx (MODIFIED): Added Prototype Launcher section with Quick Links and data-test marker
- work/hos/services/web/index.html (MODIFIED): Added prototype-launcher-marker HTML comment
- ops/frontend_smoke.ps1 (MODIFIED): Fixed deterministic output (FAIL on missing marker, no blank runs)
- docs/PROOFS/wp44_prototype_spine_smoke_pass.md - Proof document

**Commands:**
```powershell
# Run prototype smoke
.\ops\prototype_smoke.ps1

# Run frontend smoke
.\ops\frontend_smoke.ps1

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** docs/PROOFS/wp44_prototype_spine_smoke_pass.md

**Acceptance:**
- Prototype smoke script created (ops/prototype_smoke.ps1)
- Prototype Launcher UI section added (App.tsx + index.html marker)
- Frontend smoke deterministic output (no blank runs, FAIL on missing marker)
- All endpoint checks PASS (HOS core, HOS worlds, Pazar, Messaging)
- HOS Web UI marker detected (prototype-launcher-marker comment)
- All scripts: ASCII-only output, clear PASS/FAIL, exit code 0/1

**Notes:**
- **Minimal diff:** Only script creation, UI marker addition, smoke output fix
- **No refactor:** Only prototype discipline additions, no business logic changes
- **ASCII-only:** All scripts output ASCII format
- **Exit codes:** 0 (PASS) or 1 (FAIL) for all scripts

---

## WP-46: Prototype V1 Runner + Closeouts Hygiene Gate (single-main)

**Purpose:** Finalize Prototype v1 workflow with one-command local verification runner and closeouts hygiene gate to prevent WP_CLOSEOUTS.md from growing forever. Zero behavior change. Minimal diff. Ops+docs discipline only.

**Deliverables:**
- ops/prototype_v1.ps1 (NEW): One command runner that optionally starts stack, waits for endpoints, runs smokes in order, prints manual checks
- ops/closeouts_size_gate.ps1 (NEW): Gate that fails if WP_CLOSEOUTS.md exceeds budget (1200 lines) or "keep last 8" policy
- ops/closeouts_rollover.ps1 (NEW): Script that safely moves older WP sections to archive (preserves header, avoids duplicates)
- ops/ship_main.ps1 (MODIFIED): Added closeouts_size_gate before conformance (early fail)
- docs/PROOFS/wp46_prototype_v1_runner_pass.md (NEW): Proof document

**Commands:**
```powershell
# Run prototype v1 runner
.\ops\prototype_v1.ps1
# Or with stack start:
.\ops\prototype_v1.ps1 -StartStack

# Run closeouts size gate
.\ops\closeouts_size_gate.ps1

# Run closeouts rollover (if needed)
.\ops\closeouts_rollover.ps1 -Keep 8

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\closeouts_size_gate.ps1
.\ops\conformance.ps1
```

**Proof:** docs/PROOFS/wp46_prototype_v1_runner_pass.md

**Acceptance:**
- Prototype v1 runner created (optionally starts stack, waits for endpoints, runs smokes, prints manual checks)
- Closeouts size gate prevents growth (fails if > 8 WP sections or > 1200 lines)
- Closeouts rollover script safely moves older sections to archive
- Ship main includes closeouts gate (early fail before conformance)
- All gates PASS

**Notes:**
- **Minimal diff:** Only runner script, gates, rollover script, ship_main modification
- **No duplication:** Runner orchestrates existing scripts only
- **ASCII-only:** All outputs ASCII format, tokens masked
- **PowerShell 5.1:** All scripts compatible

---

## WP-45: Single-Main Ship + Prototype Flow Smoke v1 (NO PR, NO EXTRA BRANCH)

**Purpose:** Complete prototype spine with E2E flow smoke (HOS → Pazar → Messaging) and single-command ship (gates + smokes + push, no PR, no branch). Zero behavior change. Minimal diff. Smoke + ship + docs only.

**Deliverables:**
- ops/prototype_smoke.ps1 (MODIFIED): Docker ps output sanitized (ASCII-only, formatted table)
- ops/frontend_smoke.ps1 (MODIFIED): Output deterministic (ASCII sanitize, STRICT marker check)
- ops/prototype_flow_smoke.ps1 (NEW): E2E flow smoke (JWT → tenant_id → listing → messaging thread → message)
- ops/ship_main.ps1 (NEW): One command publish (gates + smokes + push, no PR)
- docs/PROOFS/wp45_prototype_flow_smoke_pass.md (NEW)
- docs/PROOFS/wp45_ship_main_pass.md (NEW)

**Commands:**
```powershell
# Run prototype flow smoke
.\ops\prototype_flow_smoke.ps1

# Run ship main
.\ops\ship_main.ps1

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** 
- docs/PROOFS/wp45_prototype_flow_smoke_pass.md
- docs/PROOFS/wp45_ship_main_pass.md

**Acceptance:**
- Prototype flow smoke: PASS (E2E flow validated)
- Ship main: PASS (all gates PASS, git sync successful)
- ASCII-only: All outputs sanitized
- Single-main: No PR, no branch, direct push to main

**Notes:**
- **Zero behavior change:** Only smoke + ship scripts
- **Minimal diff:** Only script creation
- **No refactor:** No business logic changes
- **ASCII-only:** All outputs ASCII format

---

## WP-43: Build Artefact Hygiene v1 (dist ignore + untrack, deterministic public_ready)

**Purpose:** Ensure marketplace-web build (npm run build) does not pollute the repository. public_ready_check.ps1 must always PASS with clean working tree.

**Deliverables:**
- .gitignore (MODIFIED): Added `work/marketplace-web/dist/` entry
- work/marketplace-web/dist (UNTRACKED): Removed 3 tracked dist files from git index
- docs/PROOFS/wp43_build_artefact_hygiene_pass.md - Proof document

**Commands:**
```powershell
# Untrack dist files
git rm -r --cached work/marketplace-web/dist

# Verify build does not pollute
cd work/marketplace-web; npm run build; cd ../..
git status --porcelain  # Should be clean

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** docs/PROOFS/wp43_build_artefact_hygiene_pass.md

**Acceptance:**
- Dist files untracked (3 files removed from git index)
- .gitignore updated (work/marketplace-web/dist/ added)
- Build test: New dist files created but not tracked (ignored)
- public_ready_check: PASS after commit (git status clean)
- All gates PASS

**Notes:**
- **Minimal diff:** Only .gitignore update and dist untrack, no code changes
- **No refactor:** Only hygiene fix
- **No feature changes:** Only build artefact handling
- **Deterministic:** Build artifacts are now consistently ignored

---

## WP-40: Frontend Smoke v1 (No New Dependencies, Deterministic)

**Purpose:** Establish frontend smoke test discipline for V1 prototype: omurga (worlds) must PASS before frontend test can PASS, HOS Web must be accessible and render World Directory, marketplace-web build must PASS.

**Deliverables:**
- ops/frontend_smoke.ps1 (NEW): Frontend smoke test script with worlds check dependency
- docs/PROOFS/wp40_frontend_smoke_pass.md - Proof document

**Commands:**
`powershell
# Run frontend smoke test
.\ops\frontend_smoke.ps1

# Individual checks
.\ops\world_status_check.ps1  # Must PASS first
Invoke-WebRequest http://localhost:3002  # HOS Web check
cd work\marketplace-web; npm run build  # Build check
`

**Proof:** docs/PROOFS/wp40_frontend_smoke_pass.md

**Acceptance:**
-  Frontend smoke test script created (ops/frontend_smoke.ps1)
-  Worlds check dependency enforced (fail-fast if worlds check fails)
-  HOS Web accessibility verified (status 200, world directory marker found)
-  marketplace-web build verified (npm run build PASS)
-  All steps PASS, exit code 0

**Notes:**
- **No new dependencies:** Uses existing PowerShell, Invoke-WebRequest, npm
- **Minimal diff:** Only script creation, no code changes
- **Deterministic:** Fail-fast on worlds check failure (omurga broken)
- **ASCII-only:** All outputs ASCII format

---
