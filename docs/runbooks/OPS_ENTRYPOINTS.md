# OPS Entrypoints Runbook (WP-68C)

**Purpose:** Define a single, professional entrypoint discipline for repository operations.

**Principle:** A developer can run the repo using ONLY 4 commands, and knows exactly when to use which.

---

## A) Golden 4 Commands

### (1) Prototype / Demo Verification
```powershell
.\ops\ops.ps1 prototype
```

**When to use:**
- After setting up the development environment
- Before demonstrating the prototype to stakeholders
- To verify that demo environment is ready

**Expected output:**
- `PASS`: Frontend smoke test and world status checks pass
- `FAIL`: One or more checks fail (review output for details)

**Troubleshooting:**
- If frontend smoke fails: Check that `hos-web` and `marketplace-web` containers are running
- If world status fails: Verify that `hos-api` and `pazar-api` services are accessible

---

### (2) Status / Audit
```powershell
.\ops\ops.ps1 status
```

**When to use:**
- To get a comprehensive overview of system health
- Before making significant changes
- To verify all gates and checks
- When troubleshooting issues

**Expected output:**
- Unified dashboard showing:
  - Core availability (H-OS + hos-db)
  - Service status
  - Gate results
  - Audit information

**Troubleshooting:**
- If gates fail: Review the FAIL section in output
- If services unavailable: Check Docker containers are running (`docker compose ps`)
- For detailed diagnostics: Run individual contract checks (see Leaf Scripts below)

---

### (3) Publish
```powershell
.\ops\ops.ps1 ship
```

**When to use:**
- When ready to publish changes to main branch
- After all local tests pass
- Before creating a release

**Expected output:**
- Runs all gates and smoke tests
- Pushes to main if all checks pass
- `PASS`: Changes published successfully
- `FAIL`: One or more gates failed (changes not published)

**Troubleshooting:**
- If gates fail: Fix issues and re-run
- If git push fails: Check branch protection rules and permissions
- Review output for specific failure reasons

---

### (4) Frontend Apply
```powershell
.\ops\ops.ps1 refresh          # Restart (default)
.\ops\ops.ps1 refresh -Build   # Rebuild
```

**When to use:**
- After making UI/text/layout changes (use default restart)
- After updating dependencies or build assets (use `-Build`)
- When browser cache prevents seeing changes

**Expected output:**
- `PASS`: Services restarted/rebuilt successfully
- Instructions for next steps (browser hard refresh)

**Troubleshooting:**
- If restart fails: Check Docker containers exist (`docker compose ps`)
- If rebuild fails: Check Docker build logs
- If changes still not visible: Perform hard refresh (Ctrl+F5) in browser

---

## B) Decision Table

| Scenario | Command | Notes |
|----------|---------|-------|
| UI change not showing | `.\ops\ops.ps1 refresh` + Ctrl+F5 | Default restart is usually sufficient |
| New dependencies or build assets | `.\ops\ops.ps1 refresh -Build` | Full rebuild required |
| Gate fails | `.\ops\ops.ps1 status` + read FAIL section | Review output for specific failures |
| Before demo/presentation | `.\ops\ops.ps1 prototype` | Verify environment is ready |
| Ready to publish | `.\ops\ops.ps1 ship` | Runs all gates before publishing |
| General health check | `.\ops\ops.ps1 status` | Comprehensive status overview |

---

## C) Leaf Scripts

**IMPORTANT: DO NOT RUN DIRECTLY unless instructed by a senior engineer or specific troubleshooting guide.**

Leaf scripts now live under these folders:

- **`ops/_checks/`**: gates + checks (contract, security, snapshots, smoke)
- **`ops/_tools/`**: tools + reporting (audit, snapshots, correlation, hygiene)
- **`ops/_legacy/`**: legacy pack (manual, occasional)
- **`ops/_extras/`**: prototypes + proofs + packs

**Discoverability (canonical):**

```powershell
.\ops\_extras\tools\ops_inventory.ps1
```

**Rule:** Run leaf scripts via `.\ops\ops.ps1 <command>` whenever possible (see `.\ops\ops.ps1 help`). If a specific script is not exposed as a command, use the inventory output to find its exact path under `ops/_checks` or `ops/_tools`.

---

## Troubleshooting

### If a command fails:

1. **Read the output carefully** - Most commands provide specific error messages
2. **Check prerequisites** - Ensure Docker containers are running, services are accessible
3. **Review related leaf scripts** - Some failures may require running specific diagnostic scripts
4. **Check logs** - Docker logs (`docker compose logs <service>`) may provide additional context
5. **Run ops_status** - Get comprehensive system status to identify issues

### Common Issues:

- **Frontend changes not showing**: Run `frontend_refresh.ps1 -Build` and hard refresh browser (Ctrl+F5)
- **Gates failing**: Run `ops_status.ps1` to see which specific checks are failing
- **Services unavailable**: Check Docker containers with `docker compose ps`
- **Git issues**: Ensure working directory is clean before publishing

---

## Notes

- All commands are PowerShell 5.1 compatible
- All outputs are ASCII-only
- No scripts are deleted or moved - only documentation and entrypoint discipline added
- Leaf scripts remain available for advanced troubleshooting

