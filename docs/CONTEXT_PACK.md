# CONTEXT PACK - Non-Negotiable Rules & Canonical Entrypoint

**Version:** 1.0  
**Last Updated:** 2026-01-14

## Non-Negotiable Rules

1. **NO FEATURE. NO REFACTOR. NO BEHAVIOR CHANGE.**
   - Only stabilization, standardization, cleanup
   - No app logic changes unless proven dead and covered by tests

2. **NO PASS, NO NEXT STEP**
   - Every step ends with PASS/FAIL + evidence command output
   - See `docs/runbooks/_worklog.md` for evidence

3. **Never Hard-Delete First**
   - Anything removed must be moved to `/_archive/YYYYMMDD/` with a short note
   - Rollback = move back from `_archive`

4. **Do Not Touch Secrets in Plaintext**
   - If found (.env, tokens, keys), remove from repo
   - Replace with `.env.example` + `docs/secrets` guide

5. **One Canonical Entrypoint Only**
   - Single docker compose + single ops bootstrap path
   - Everything else becomes "reference" or archived

## Canonical Entrypoint

**Compose File:** `docker-compose.yml` (root)

**Boot Command:**
```powershell
docker compose up -d --build
```

**Health Check:**
```powershell
.\ops\verify.ps1
```

## Active Work Order Pointer

See `docs/CURRENT.md` for current active work order.

## Last PASS Evidence Pointer

See `docs/runbooks/_worklog.md` for append-only PASS/FAIL evidence lines.

## Repository Structure

```
.
├── docker-compose.yml          # CANONICAL compose (hos + pazar)
├── ops/
│   ├── stack_up.ps1            # Canonical boot wrapper
│   └── verify.ps1              # Health check
├── docs/
│   ├── CURRENT.md              # Active work order
│   ├── CONTEXT_PACK.md         # This file
│   ├── START_HERE.md           # Entry point for new contributors
│   └── runbooks/
│       └── _worklog.md         # PASS/FAIL evidence log
└── work/
    ├── hos/                    # H-OS service
    └── pazar/                  # Pazar service
```

## Boot Paths

**Canonical (Recommended):**
- `docker compose up -d --build` (root)

**Alternative (Obs Profile):**
- `cd work/hos && docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d --build --profile obs`

**Reference (Not Canonical):**
- `work/hos/docker-compose*.yml` (7 files - for obs profile only)



















