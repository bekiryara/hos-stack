# Release Planning

## When to Tag Baseline Patches

Tag baseline patches when:
1. **Baseline stability fixes**: Fixes to baseline checks, health endpoints, or bring-up process
2. **Critical security fixes**: Security fixes affecting baseline services
3. **Documentation corrections**: Critical corrections to baseline documentation

**Do NOT tag for:**
- Feature additions (use feature tags)
- Non-baseline bug fixes
- Documentation improvements (unless baseline-critical)

## Tag Format

**Baseline patches:**
```
BASELINE-YYYY-MM-DD
```

**Examples:**
- `BASELINE-2026-01-15` - Baseline patch from Jan 15, 2026
- `BASELINE-2026-01-20` - Baseline patch from Jan 20, 2026

## Required Proofs Before Tag

Before creating a baseline tag, ensure:

1. **Baseline checks pass:**
   ```powershell
   .\ops\ops.ps1 baseline-status
   .\ops\ops.ps1 verify
   ```

2. **Conformance passes:**
   ```powershell
   .\ops\ops.ps1 conformance
   ```

3. **CHANGELOG entry exists:**
   - Entry for baseline-impacting change in CHANGELOG.md
   - Format: Keep a Changelog format

4. **Proof entry exists:**
   - Proof entry in `docs/PROOFS/PASS_LOG.md` for the change
   - Includes verification commands and a short expected vs actual note

5. **Release note generated:**
   ```powershell
   .\ops\_legacy\legacy.ps1 release-note -Tag BASELINE-2026-01-15
   ```

## Tagging Process

1. **Verify baseline:**
   ```powershell
   .\ops\ops.ps1 baseline-status
   .\ops\ops.ps1 verify
   ```

2. **Generate release note:**
   ```powershell
   .\ops\_legacy\legacy.ps1 release-note -Tag BASELINE-2026-01-15
   ```

3. **Create tag:**
   ```powershell
   git tag -a BASELINE-2026-01-15 -m "BASELINE: <description>"
   git push origin BASELINE-2026-01-15
   ```

4. **Verify tag:**
   ```powershell
   git checkout BASELINE-2026-01-15
   .\ops\ops.ps1 baseline-status
   git checkout main
   ```

## Release Cadence

- **Baseline patches**: As needed (when baseline stability fixes are required)
- **Feature releases**: Per roadmap (not covered by baseline tags)
- **Security patches**: Immediately (baseline tags)

## Related Documentation

- **Baseline rules**: `docs/SPEC.md` and `docs/RULES.md`
- **Current baseline**: `docs/CURRENT.md`
- **Publish discipline**: `docs/DEV_DISCIPLINE.md`






