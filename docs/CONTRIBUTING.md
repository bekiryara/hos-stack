# CONTRIBUTING - Contribution Guidelines

## Commit Message Convention

### Format

```
<type>: <subject>

<body (optional)>

<footer (optional)>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **ops**: Operations/scripts changes
- **refactor**: Code refactoring (no behavior change)
- **test**: Test additions or changes
- **chore**: Maintenance tasks

### Examples

**Good:**
```
ops: Add baseline_status.ps1 for baseline health checks

Creates read-only baseline status script that checks:
- Container status
- H-OS health endpoint
- Pazar health endpoint

Exit codes: 0=PASS, 1=FAIL
```

```
docs: Update CURRENT.md with baseline definition

Single source of truth now includes:
- Core services list
- Port mappings
- Green check definitions
```

**Bad:**
```
update files
```
```
WIP: fix stuff
```

## Pull Request Convention

### PR Title Format

```
<type>: <brief description>
```

Examples:
- `ops: Add daily snapshot script`
- `docs: Create ONBOARDING.md for newcomers`
- `fix: Resolve Pazar health check timeout`

### PR Description Template

```markdown
## Summary
Brief description of changes.

## Changes
- List of changes
- Each change on a new line

## Verification
- [ ] `.\ops\verify.ps1` passes
- [ ] `.\ops\baseline_status.ps1` passes (if applicable)
- [ ] Documentation updated (if applicable)

## Related
- Closes #<issue-number> (if applicable)
```

## CHANGELOG Discipline

### When to Update CHANGELOG

**Must update:**
- Baseline-affecting changes (infrastructure, health checks, verification scripts)
- Breaking changes
- New features
- Significant bug fixes

**Do NOT update:**
- Minor documentation typos
- Internal refactoring (unless it changes behavior)
- Test-only changes

### Format

Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format:

```markdown
## [Unreleased]

### Added
- New features

### Changed
- Changes to existing functionality

### Fixed
- Bug fixes

### Removed
- Removed features (if any)
```

### Entry Format

Each entry should be:
- **Descriptive**: Explain what changed and why
- **Actionable**: Include verification steps or proof docs
- **Linked**: Reference related proof docs in `docs/PROOFS/`

Example:
```markdown
- **BASELINE STATUS SCRIPT**: Added `ops/baseline_status.ps1` for read-only baseline health checks. Checks container status, H-OS health (`/v1/health`), and Pazar health (`/up`). Exit codes: 0=PASS, 1=FAIL. See `docs/PROOFS/baseline_pass.md` for verification.
```

## Code Review Checklist

### For Reviewers

- [ ] Changes maintain baseline (verify.ps1 still passes)
- [ ] No breaking changes to frozen items (see `docs/DECISIONS.md`)
- [ ] Documentation updated (if applicable)
- [ ] CHANGELOG updated (if baseline-affecting)
- [ ] Proof doc created (if new feature/fix)

### For Authors

- [ ] Self-review: Does the change make sense?
- [ ] Tests pass: `.\ops\verify.ps1` and `.\ops\baseline_status.ps1`
- [ ] Documentation: Updated relevant docs
- [ ] CHANGELOG: Added entry if baseline-affecting
- [ ] Proof: Created proof doc in `docs/PROOFS/` if needed

## Branch Naming

**Preferred:**
- `feature/<description>` - New features
- `fix/<description>` - Bug fixes
- `docs/<description>` - Documentation
- `ops/<description>` - Operations/scripts

**Avoid:**
- `wip/*` - Use draft PRs instead
- `test/*` - Too generic
- `update/*` - Too vague

## No PASS, No Merge Rule

**CRITICAL**: Before submitting a PR, you MUST:

1. **Run baseline checks**: 
   ```powershell
   .\ops\verify.ps1
   .\ops\conformance.ps1
   ```
   Both must return exit code 0 (PASS)

2. **Create proof doc**: Every change must include a proof file under `docs/PROOFS/` with:
   - What changed
   - Verification commands run
   - Expected vs actual outputs
   - PASS/FAIL conclusion

3. **Paste outputs**: Include actual command outputs in proof doc (do not fake PASS)

**If checks fail**: Fix issues before submitting PR. CI will reject PRs with failing baseline checks.

## Baseline Preservation

**CRITICAL**: All changes must maintain baseline functionality:

1. **Health checks must pass**: `.\ops\verify.ps1` returns 0
2. **No breaking changes**: See `docs/DECISIONS.md` for frozen items
3. **Documentation updated**: If behavior changes, update `docs/CURRENT.md`
4. **Proof provided**: Create proof doc in `docs/PROOFS/` for significant changes

## Questions?

- Read `docs/CURRENT.md` for stack overview
- Read `docs/DECISIONS.md` for frozen items
- Read `docs/ONBOARDING.md` for setup
- Run `.\ops\triage.ps1` for troubleshooting


