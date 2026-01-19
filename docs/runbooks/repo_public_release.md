# Repository Public Release Runbook

This runbook guides you through preparing the repository for public GitHub release.

## Prerequisites

- PowerShell 5.1 or later
- Git repository initialized
- All changes committed or stashed

## Step 1: Run Secret Scan

**Purpose:** Identify any secrets or sensitive data in tracked files.

```powershell
.\ops\secret_scan.ps1
```

**Expected Output:**
- `=== SECRET SCAN: PASS ===` - No secrets detected, safe to proceed
- `=== SECRET SCAN: FAIL ===` - Secrets detected, remediation required

**If FAIL:**
1. Review the findings
2. Distinguish between:
   - **Real secrets** (production credentials, API keys, passwords)
   - **Test/example values** (test tokens, dev placeholders)
3. Follow remediation steps below

## Step 2: Remediation (If Secrets Found)

### A) Remove Real Secrets

**For production secrets:**
1. **Rotate immediately** - Assume secrets are compromised
2. Remove from tracked files
3. Use environment variables or secret management
4. Update `.gitignore` to prevent future commits

**For test/example values:**
- If in documentation (CHANGELOG.md, PROOFS/*.md): Consider redacting or using placeholders
- If in test scripts: Ensure they're clearly marked as test-only
- If in docker-compose.yml: Move to `.env` file (not tracked)

### B) History Cleanup (If Secrets Were Committed)

**Option 1: git filter-repo (Recommended)**
```powershell
# Install git-filter-repo first: pip install git-filter-repo

# Remove secret from history
git filter-repo --path docker-compose.yml --invert-paths
# Or remove specific lines:
git filter-repo --path docker-compose.yml --use-base-name --invert-blobs --blob-callback '
if b"password" in blob.data():
    skip_this_blob = True
'
```

**Option 2: Fresh Public Mirror**
```powershell
# Create new repo without history
git checkout --orphan public-main
git add .
git commit -m "Initial public release"
# Push to new public repo
```

### C) Confirm What to Rotate

**Checklist:**
- [ ] APP_KEY (Laravel) - Generate new: `php artisan key:generate`
- [ ] Database passwords - Change in production
- [ ] JWT secrets - Rotate if exposed
- [ ] API keys - Revoke and regenerate
- [ ] OAuth client secrets - Regenerate in provider

## Step 3: Run Public Ready Check

**Purpose:** Verify repository is safe for public release.

```powershell
.\ops\public_ready_check.ps1
```

**Checks:**
- Secret scan passes
- Git working directory is clean
- `.env` files are not tracked
- `vendor/` is not tracked

**Expected Output:**
- `=== PUBLIC READY CHECK: PASS ===` - Safe to push
- `=== PUBLIC READY CHECK: FAIL ===` - Fix issues before pushing

## Step 4: Final Verification

```powershell
# 1. Check git status
git status --porcelain
# Should be empty

# 2. Verify .env is ignored
git ls-files -- .env
# Should return nothing

# 3. Run public ready check
.\ops\public_ready_check.ps1
# Should pass

# 4. Review .gitignore
cat .gitignore
# Should include .env, vendor/, node_modules/, etc.
```

## Step 5: Create GitHub Repository

**If all checks pass:**

1. Create new repository on GitHub (public)
2. Add remote:
   ```powershell
   git remote add public <github-repo-url>
   ```
3. Push:
   ```powershell
   git push public main
   ```

## Post-Release Checklist

- [ ] Update README.md with public repo rules
- [ ] Verify CI workflows work on public repo
- [ ] Test PR creation and CI gates
- [ ] Document any required environment setup
- [ ] Add CONTRIBUTING.md if needed

## Troubleshooting

**Secret scan finds test values:**
- These are false positives if clearly marked as test-only
- Consider adding exception patterns to `secret_scan.ps1`
- Or redact in documentation

**Git history contains secrets:**
- Use `git filter-repo` to clean history
- Or create fresh public mirror
- **Important:** Notify team if secrets were exposed

**Public ready check fails:**
- Fix each issue reported
- Re-run check until all pass
- Do not skip checks

## Related Files

- `ops/secret_scan.ps1` - Secret scanning script
- `ops/public_ready_check.ps1` - Public readiness verification
- `.gitignore` - Ignored files list
- `.github/workflows/` - CI/CD workflows

