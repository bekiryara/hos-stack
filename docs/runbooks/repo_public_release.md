# Repo Public Release Runbook

**Goal:** Publish the repository (public) without leaking secrets, generated artifacts, or documentation drift.

This runbook is referenced by `ops/public_ready_check.ps1` and is the **single source of truth** for the public-release sequence.

---

## Golden Path (Single Chain)

1) **Full baseline gates**

```powershell
.\ops\ops_run.ps1 -Profile Full
```

2) **Publish (gates + push)**

```powershell
.\ops\ops.ps1 ship
```

**Rule:** No PASS → no next step. If either fails, fix the cause and re-run.

---

## What `ops.ps1 ship` Enforces

`.\ops\ops.ps1 ship` is the publish entrypoint. It fails fast on:

- **Required publish gates (FAIL if missing or non-zero)**
  - `ops/update_code_index.ps1 -DryRun -Gate`
  - `ops/verify_wp_closeouts.ps1 -Gate`
  - `ops/secret_scan.ps1`
  - `ops/public_ready_check.ps1`
  - `ops/repo_payload_guard.ps1`
  - `ops/closeouts_size_gate.ps1`
  - `ops/conformance.ps1`
  - `ops/frontend_smoke.ps1`

- **Optional gates (SKIP if not present)**
  - `ops/prototype_smoke.ps1`
  - `ops/prototype_flow_smoke.ps1`

**Policy:** Optional gates may be absent; required gates must exist and must PASS.

---

## Common Failure Modes & Fixes

- **Secrets found**
  - Run: `.\ops\secret_scan.ps1`
  - Follow: `REMEDIATION_SECRETS.md`

- **Repo payload guard fails (generated artifacts tracked)**
  - Run: `.\ops\repo_payload_guard.ps1`
  - Remove tracked generated files, add to `.gitignore`, re-commit

- **Closeouts policy fails**
  - Run: `.\ops\closeouts_rollover.ps1 -Keep 8`
  - Ensure `docs/WP_CLOSEOUTS.md` stays within policy

- **CODE_INDEX gate fails**
  - Run: `.\ops\update_code_index.ps1`
  - Commit the updated `docs/CODE_INDEX.md`

- **WP_CLOSEOUTS proof links drift**
  - Run: `.\ops\verify_wp_closeouts.ps1`
  - Fix missing proof/script references

---

## Proof / Evidence

For a public release decision, keep these outputs:

```powershell
.\ops\public_ready_check.ps1
.\ops\repo_payload_guard.ps1
.\ops\closeouts_size_gate.ps1
```

