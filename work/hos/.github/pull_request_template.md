## Summary
- What changed?
- Why?

## Checklist
- [ ] I ran a local quick check: `.\ops\check.ps1 -SkipAuth`
- [ ] If I touched API behavior, I updated tests in `services/api/test/`
- [ ] If I added/changed migrations, I verified `npm run migrate` and considered backward-compat
- [ ] If I changed compose/ops, I verified `ops/bootstrap.ps1` + `ops/smoke.ps1 -SkipAuth`
- [ ] Docs updated where needed (`README.md`, `STATUS.md`, `RUNBOOK.md`, `RELEASE.md`)
- [ ] Security considerations reviewed (secrets mode, `COOKIE_SECURE`, Grafana defaults)


