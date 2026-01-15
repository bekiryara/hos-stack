# Commit Rules

## Commit Message Format

```
<prefix>: <subject>

<body (optional)>

<footer (optional)>
```

## Prefixes

- **chore:** Maintenance tasks, dependencies, tooling
- **ops:** Operations scripts, CI/CD, automation
- **docs:** Documentation only changes
- **fix:** Bug fixes
- **feat:** New features

## Examples

### Good Commit Messages

```
ops: Add graveyard_check.ps1 for _graveyard policy enforcement

Ensures files moved to _graveyard have accompanying note files.

Fixes: #123
```

```
docs: Update CURRENT.md with new service ports

Added pazar-app port 8080 to port mappings section.
```

```
fix: Resolve baseline_status.ps1 exit code issue

baseline_status was returning wrong exit code on SKIP.
Now correctly returns 0 for SKIP, 1 for FAIL.

See: docs/PROOFS/baseline_status_fix.md
```

```
feat: Add daily snapshot automation

Added ops/daily_snapshot.ps1 for automated daily evidence capture.

See: docs/PROOFS/daily_snapshot_pass.md
```

### Bad Commit Messages

```
update files
```

```
WIP
```

```
fix stuff
```

## Folder Moves

**Rule:** Any folder move must include a note or proof doc.

**Required:**
- If moving to `_graveyard/`: Add entry to `_graveyard/POLICY.md` or create note file
- If moving from `_graveyard/`: Document in PR description why it's being restored

**Example:**
```
chore: Move unused scripts to _graveyard

Moved ops/old_script.ps1 to _graveyard/ops/old_script.ps1

Reason: Not referenced by any active workflow.
Restore: git log --all --full-history -- _graveyard/ops/old_script.ps1
Note: Added entry to _graveyard/POLICY.md
```

## Breaking Changes

**Rule:** Breaking changes must:
1. Update `docs/DECISIONS.md` with decision rationale
2. Update `docs/CURRENT.md` if baseline definition changes
3. Add `docs/PROOFS/` entry with migration steps
4. Update CHANGELOG with breaking change notice

**Example:**
```
fix: Change default port from 3000 to 3001

BREAKING CHANGE: Default port changed. Update local configs.

- Updated docs/CURRENT.md
- Added docs/PROOFS/port_change_migration.md
- Updated CHANGELOG.md

Migration: Update docker-compose.yml port mappings.
```

## Commit Scope

- **One logical change per commit**
- **Commit often, push when ready for review**
- **Use meaningful subjects** (50 chars max recommended)

## References

- **Fixes:** `Fixes: #123` (closes issue)
- **See:** `See: docs/PROOFS/xyz.md` (proof doc)
- **Related:** `Related to: #456` (related issue)


