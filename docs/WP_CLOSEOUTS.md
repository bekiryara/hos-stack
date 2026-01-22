# WP Closeouts - Workspace Package Summaries

**Last Updated:** 2026-01-22  
**Purpose:** Short summaries of completed Workspace Packages (WP) with deliverables, commands, and proof evidence.

**Archive:** Older WP entries have been moved to archive files to keep this index small:
- [docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026.md](closeouts/WP_CLOSEOUTS_ARCHIVE_2026.md)
- [docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026_B.md](closeouts/WP_CLOSEOUTS_ARCHIVE_2026_B.md)

Only the last 8 WP entries are shown here.

---
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

## WP-46: Prototype Demo + Closeouts Rollover (one-command demo, zero duplication)

**Purpose:** Add tiny orchestrator for prototype demo (calls existing scripts only, no duplication). Fix WP_CLOSEOUTS growth by keeping last 8 entries and moving older entries to archive. Improve failure messaging for known flake (prototype_flow_smoke JWT/token failures).

**Deliverables:**
- ops/prototype_demo.ps1 (NEW): Orchestrator that calls prototype_smoke and prototype_flow_smoke, prints click targets on PASS
- ops/prototype_flow_smoke.ps1 (MODIFIED): Better error hinting around JWT/token acquisition (actionable hints on failure)
- docs/WP_CLOSEOUTS.md (MODIFIED): Kept last 8 WP entries (WP-38 through WP-45), moved WP-27 through WP-37 to archive
- docs/closeouts/WP_CLOSEOUTS_ARCHIVE_2026_B.md (NEW): Archive file containing WP-27 through WP-37
- docs/PROOFS/wp46_prototype_demo_pass.md (NEW): Proof document
- docs/PROOFS/wp46_closeouts_rollover_pass.md (NEW): Proof document

**Commands:**
```powershell
# Run prototype demo
.\ops\prototype_demo.ps1

# Run gates
.\ops\secret_scan.ps1
.\ops\public_ready_check.ps1
.\ops\conformance.ps1
```

**Proof:** 
- docs/PROOFS/wp46_prototype_demo_pass.md
- docs/PROOFS/wp46_closeouts_rollover_pass.md

**Acceptance:**
- Prototype demo orchestrator created (calls existing scripts, no duplication)
- JWT failure hints improved (actionable remediation steps)
- WP_CLOSEOUTS rollover complete (last 8 WP only, archive created)
- All gates PASS

**Notes:**
- **Minimal diff:** Only orchestrator script, error hints, docs rollover
- **No duplication:** Orchestrator only calls existing scripts
- **ASCII-only:** All outputs ASCII format

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
