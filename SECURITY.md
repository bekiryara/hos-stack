# Security Policy

## Supported Versions

We support security updates for the current baseline version. See [`docs/RELEASES/BASELINE.md`](docs/RELEASES/BASELINE.md) for baseline information.

## Reporting a Vulnerability

If you discover a security vulnerability, please **do not** open a public issue. Instead:

1. Email security concerns to the repository maintainers
2. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will respond within 48 hours and work with you to address the issue.

## Secrets Policy

**CRITICAL:** Never commit secrets to the repository.

### What NOT to Commit

- **Secrets files**: `work/hos/secrets/*.txt` (should be in `.gitignore`)
- **Environment files**: `.env`, `.env.*` (should be in `.gitignore`)
- **Credentials**: API keys, passwords, tokens, certificates
- **Personal data**: User information, sensitive configuration

### What IS Tracked

- **Example files**: `work/pazar/docs/env.example` (template, no real values)
- **Documentation**: Security best practices, configuration guides

### If You Accidentally Commit Secrets

1. **Immediately rotate** the exposed secrets (change passwords, regenerate keys)
2. **Remove from git history** (use `git filter-branch` or BFG Repo-Cleaner)
3. **Notify maintainers** if secrets were pushed to remote
4. **Update `.gitignore`** to prevent future commits

### Local Development

- Use `docker-compose.override.yml` for local environment variables (not tracked)
- Use `work/hos/secrets/` for local secret files (not tracked)
- Never share real credentials in PRs, issues, or documentation

## Security Best Practices

1. **Keep dependencies updated**: Regularly update Docker images and package dependencies
2. **Use secrets management**: Prefer environment variables or secret files over hardcoded values
3. **Review PRs carefully**: Check for accidental secret commits
4. **Run security scans**: Use tools like `docker scan` or dependency scanners
5. **Follow principle of least privilege**: Services should only have access to what they need

## Security Checklist for PRs

Before submitting a PR, ensure:
- [ ] No secrets in code or configuration
- [ ] No hardcoded credentials
- [ ] `.gitignore` updated if new secret locations added
- [ ] Dependencies reviewed for known vulnerabilities
- [ ] Security-sensitive changes documented





