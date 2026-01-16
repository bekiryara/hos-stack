---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''
---

## Description

A clear and concise description of what the bug is.

## Steps to Reproduce

1. Run command: `...`
2. See error: `...`

## Expected Behavior

What should happen?

## Actual Behavior

What actually happens?

## Environment

- OS: [e.g., Windows 10, macOS 13]
- Docker version: [e.g., 20.10.21]
- PowerShell version: [e.g., 5.1]

## Logs & Outputs

### Verification Output

```powershell
.\ops\verify.ps1
```

**Output:**
```
(paste output here)
```

### Triage Output

```powershell
.\ops\triage.ps1
```

**Output:**
```
(paste output here)
```

### Container Logs

```powershell
docker compose logs pazar-app
```

**Output:**
```
(paste relevant logs here)
```

## Additional Context

Add any other context about the problem here.

## Checklist

- [ ] I have run `.\ops\verify.ps1` and included the output
- [ ] I have run `.\ops\triage.ps1` and included the output
- [ ] I have included relevant container logs
- [ ] I have checked `docs/CURRENT.md` for known issues





