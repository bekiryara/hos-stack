# Repo Public Release Runbook

**Goal:** Publish the repository (public) without leaking secrets, generated artifacts, or documentation drift.

This runbook is referenced by `ops/public_ready_check.ps1` and is the **single source of truth** for the public-release sequence.

---

## Golden Path (Single Chain)

1) **Full baseline gates**

```powershell
.\ops\ops.ps1 run -Profile Full
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
  - `ops/_checks/update_code_index.ps1 -DryRun -Gate`
  - `ops/_checks/verify_wp_closeouts.ps1 -Gate`
  - `.\ops\ops.ps1 secret-scan`
  - `.\ops\ops.ps1 public-ready`
  - `.\ops\ops.ps1 repo-payload-guard`
  - `.\ops\ops.ps1 closeouts-size-gate`
  - `.\ops\ops.ps1 conformance`
  - `.\ops\ops.ps1 frontend-smoke`

- **Optional gates (SKIP if not present)**
  - `ops/prototype_smoke.ps1`
  - `ops/prototype_flow_smoke.ps1`

**Policy:** Optional gates may be absent; required gates must exist and must PASS.

---

## Common Failure Modes & Fixes

- **Secrets found**
  - Run: `.\ops\ops.ps1 secret-scan`
  - Follow: `REMEDIATION_SECRETS.md`

- **Repo payload guard fails (generated artifacts tracked)**
  - Run: `.\ops\ops.ps1 repo-payload-guard`
  - Remove tracked generated files, add to `.gitignore`, re-commit

- **Closeouts policy fails**
  - Run: `.\ops\_tools\closeouts_rollover.ps1 -Keep 8`
  - Ensure `docs/WP_CLOSEOUTS.md` stays within policy

- **CODE_INDEX gate fails**
  - Run: `.\ops\ops.ps1 update-code-index`
  - Commit the updated `docs/CODE_INDEX.md`

- **WP_CLOSEOUTS proof links drift**
  - Run: `.\ops\ops.ps1 verify-wp-closeouts`
  - Fix missing proof/script references

---

## Proof / Evidence

For a public release decision, keep these outputs:

```powershell
.\ops\ops.ps1 public-ready
.\ops\ops.ps1 repo-payload-guard
.\ops\ops.ps1 closeouts-size-gate
```

