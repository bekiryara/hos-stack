# Repository Hygiene Runbook

## Purpose

This runbook defines rules for maintaining repository cleanliness and preventing drift.

## Rules for Adding New Files

### ✅ Allowed Locations

- **Application code**: `work/hos/`, `work/pazar/`
- **Operations scripts**: `ops/`
- **Documentation**: `docs/`
- **Configuration**: Root level (docker-compose.yml, .gitignore, etc.)
- **CI/CD**: `.github/`

### ❌ NOT Allowed in Root

- **Log files**: `*.log`, `*.txt` (unless documentation)
- **Dump files**: `*.dump`, `*.sql` (unless in `_archive/`)
- **Backup files**: `*.bak`, `*.backup`
- **Temporary files**: `*.tmp`, `*.temp`
- **Archive files**: `*.zip`, `*.rar`, `*.tar.gz` (unless in `_archive/`)
- **Vendor/node_modules**: Should be in project directories or `.gitignore`d

### ✅ When to Use _graveyard/

Use `_graveyard/` for:
- **Deprecated code**: Code that's no longer used but might be needed for reference
- **Experimental code**: One-off scripts or experiments
- **Legacy code**: Old implementations replaced by new ones
- **Dead code**: Code that's confirmed unused

**Rules:**
1. **Never delete** - Always move to `_graveyard/`
2. **Add NOTE file** - Create `filename.NOTE.md` explaining:
   - Why it was moved
   - When it was moved
   - How to restore if needed
3. **Update POLICY.md** - Add entry to `_graveyard/POLICY.md`
4. **Commit together** - Move + NOTE + POLICY.md update in same commit

**Example:**
```
_graveyard/ops/old_script.ps1
_graveyard/ops/old_script.NOTE.md
_graveyard/POLICY.md (updated)
```

### ✅ When to Use _archive/

Use `_archive/` for:
- **Daily snapshots**: `_archive/daily/YYYYMMDD-HHmmss/` (auto-generated)
- **Release bundles**: `_archive/releases/` (release artifacts)
- **Temporary dumps**: One-time exports, database dumps (temporary)
- **Audit records**: `_archive/audits/` (compliance records)

**Rules:**
1. **Temporary by nature** - These are not permanent code
2. **Auto-generated OK** - Daily snapshots are auto-generated
3. **Manual cleanup** - Periodically clean old archives to save space
4. **Not tracked** - Most `_archive/` contents are in `.gitignore`

## File Naming Rules

### ✅ Good Names
- `verify.ps1`
- `baseline_status.ps1`
- `docs/CURRENT.md`
- `work/pazar/routes/web.php`

### ❌ Bad Names (Non-ASCII)
- `doğrulama.ps1` (Turkish characters)
- `验证.ps1` (Chinese characters)
- `проверка.ps1` (Cyrillic)

**Rule**: Use ASCII-only characters for file and folder names.

## Secrets Policy

### ❌ Never Commit
- `work/hos/secrets/*.txt` (real secrets)
- `.env` files (real values)
- `*.key`, `*.pem` (private keys)
- Files with `secret`, `password`, `token` in name (unless examples)

### ✅ OK to Commit
- `work/pazar/docs/env.example` (template)
- `work/hos/secrets/README.md` (documentation)
- Example files with `.example` or `.template` suffix

## Large Files

### ⚠️ Before Adding Large Files (>10MB)

1. **Check if necessary**: Can it be generated instead?
2. **Consider alternatives**: Use external storage, CDN, or LFS
3. **Document why**: Add note explaining why large file is needed
4. **Review impact**: Large files slow down git operations

### ✅ Recommended

- Use Git LFS for large binary files
- Store large files in external storage
- Generate files during build instead of committing

## CI Guard Checks

The `ops/ci_guard.ps1` script automatically checks:

1. **Forbidden root artifacts**: `*.zip`, `*.rar`, `*.bak`, `*.tmp`
2. **Dump/export files**: Outside `_archive/` or `_graveyard/`
3. **Tracked secrets**: Secret files committed to git
4. **Non-ASCII paths**: File/folder names with non-ASCII characters

**Run locally before committing:**
```powershell
.\ops\ci_guard.ps1
```

## Repository Inventory Report

Generate a report of repository contents:

```powershell
.\ops\repo_inventory_report.ps1
```

This shows:
- Largest 30 files (MB)
- Files that shouldn't be in root
- Node modules/vendor in wrong places

**Note**: This is a REPORT ONLY. No files are moved automatically.

## Cleanup Workflow

### Weekly Cleanup

1. Run inventory report:
   ```powershell
   .\ops\repo_inventory_report.ps1
   ```

2. Review suspicious files

3. Move to appropriate location:
   - Deprecated code → `_graveyard/` (with NOTE)
   - Temporary dumps → `_archive/` (if needed for reference)
   - Delete if truly unnecessary (after review)

4. Clean old archives:
   ```powershell
   # Review _archive/daily/ for old snapshots
   # Delete snapshots older than 30 days (if disk space is concern)
   ```

## Checklist Before Committing

- [ ] No forbidden files in root (`*.zip`, `*.bak`, `*.tmp`)
- [ ] No secrets committed (check `git ls-files` for secrets)
- [ ] File names are ASCII-only
- [ ] Large files (>10MB) reviewed and justified
- [ ] `.\ops\ci_guard.ps1` passes
- [ ] `.\ops\repo_inventory_report.ps1` reviewed (if adding new files)

## Related Documentation

- **Graveyard Policy**: `_graveyard/POLICY.md`
- **Security Policy**: `SECURITY.md`
- **Contributing**: `docs/CONTRIBUTING.md`





