## What Changed

Brief description of what this PR changes.

## Why

Reason for this change (problem it solves, feature it adds).

## Risk

Potential risks or breaking changes.

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

Commands to verify this change works:

```powershell
# Example:
.\ops\verify.ps1
.\ops\baseline_status.ps1
# Add specific commands for this PR
```

## Related

- Closes #<issue-number>
- Related to #<issue-number>


