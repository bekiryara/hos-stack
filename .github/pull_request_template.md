## SPEC Reference

**REQUIRED:** Reference to SPEC.md section(s) this PR implements or modifies.

Format: `VAR — §X.Y` (if section exists) or `YOK → EK — §X.Y` (if adding new section)

Example: `VAR — §24.4` or `YOK → EK — §25.2`

**Note:** This line MUST be present in PR description for CI gate to pass. See SPEC §8.1.

## What Changed

Brief description of what this PR changes.

## Why

Reason for this change (problem it solves, feature it adds).

## Contracts Changed?

**REQUIRED:** Does this PR change API contracts or database schema?

- [ ] Yes (API contract changed)
- [ ] Yes (DB schema changed)
- [ ] No (no contract changes)

If yes, list changes:
- API: ...
- DB: ...

## Risk

Potential risks or breaking changes (max 5 sentences):
1. Risk 1
2. Risk 2
3. Risk 3

## Rollback

How to rollback this change if needed.

---

## Checklist

- [ ] Baseline passes locally: `.\ops\verify.ps1`
- [ ] Conformance passes: `.\ops\conformance.ps1`
- [ ] Baseline status passes: `.\ops\baseline_status.ps1`
- [ ] Proof doc added under `docs/PROOFS/` (if code changed)
- [ ] CHANGELOG updated (if baseline-impacting change)
- [ ] `docs/CURRENT.md` updated (if ports/services changed)
- [ ] Daily snapshot attached: `_archive/daily/YYYYMMDD-HHmmss/` (run `.\ops\daily_snapshot.ps1`)

## Proof Commands

**REQUIRED:** Commands to verify this change works. MUST include `ops/doctor` and `ops/smoke` outputs.

```powershell
# Example:
.\ops\doctor.ps1
.\ops\smoke.ps1
.\ops\verify.ps1
.\ops\baseline_status.ps1
# Add specific commands for this PR
```

## Proof Outputs

**REQUIRED:** Attach outputs from proof commands above:
- `ops/doctor.ps1` output: [attach or paste]
- `ops/smoke.ps1` output: [attach or paste]

## Proof Doc Path

Path to proof document (if applicable):
- `docs/PROOFS/your_proof_doc.md`

## Related

- Closes #<issue-number>
- Related to #<issue-number>


