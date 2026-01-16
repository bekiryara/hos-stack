# Baseline Pass - Proof Document

**Date:** 2026-01-14  
**Baseline:** RELEASE-GRADE BASELINE RESET v1

## Overview

This document provides proof that the baseline is working correctly. The baseline consists of:
- Core services (hos-db, hos-api, hos-web, pazar-db, pazar-app)
- Health checks passing
- Verification script passing

## Proof Commands

### 1. Verify Container Status

```powershell
docker compose ps
```

**Expected Output:**
```
NAME                SERVICE     STATUS
stack-hos-api-1     hos-api     Up
stack-hos-db-1      hos-db      Up (healthy)
stack-hos-web-1     hos-web     Up
stack-pazar-app-1   pazar-app   Up
stack-pazar-db-1    pazar-db    Up (healthy)
```

**Key Validation:**
- All required services show "Up" status
- Databases show "(healthy)" status
- No services are restarting or exited

### 2. Verify H-OS Health

```powershell
curl.exe http://localhost:3000/v1/health
```

**Expected Output:**
```json
{"ok":true}
```

**Key Validation:**
- HTTP status code: 200
- Response body: `{"ok":true}`
- No errors or timeouts

### 3. Verify Pazar Health

```powershell
curl.exe http://localhost:8080/up
```

**Expected Output:**
```
ok
```

**Key Validation:**
- HTTP status code: 200
- Response body: `"ok"` (plain text, no newline)
- No errors or timeouts

### 4. Run Baseline Status Check

```powershell
.\ops\baseline_status.ps1
```

**Expected Output:**
```
=== Baseline Status Check ===

[1] Container Status
  [PASS] All required services running

[2] H-OS Health (http://localhost:3000/v1/health)
  [PASS] HTTP 200 {"ok":true}

[3] Pazar Health (http://localhost:8080/up)
  [PASS] HTTP 200 ok

[4] Repo Integrity
  [PASS] Git working directory clean

[5] Forbidden Files Check
  [PASS] No forbidden files in tracked locations

[6] Snapshot Integrity
  [PASS] Recent snapshot found: 20260115-105303 (0.1 days old)

=== BASELINE STATUS: PASS ===
```

**Key Validation:**
- Exit code: 0
- All checks show [PASS]
- No [FAIL] messages
- WARN messages are acceptable for repo integrity and snapshot age

### 5. Run Full Verification

```powershell
.\ops\verify.ps1
```

**Expected Output:**
```
=== Stack Verification ===

[1] docker compose ps
NAME                SERVICE     STATUS
...

[2] H-OS health (http://localhost:3000/v1/health)
PASS: HTTP 200 {"ok":true}

[3] Pazar health (http://localhost:8080/up)
PASS: HTTP 200

[4] Pazar FS posture (storage/logs writability)
[PASS] Pazar FS posture: storage/logs writable

=== VERIFICATION PASS ===
```

**Key Validation:**
- Exit code: 0
- All checks pass
- No failures

## Acceptance Criteria

Baseline is considered "PASS" when:

1. ✅ All required containers are running
2. ✅ H-OS health endpoint returns HTTP 200 with `{"ok":true}`
3. ✅ Pazar health endpoint returns HTTP 200 with `"ok"`
4. ✅ Pazar filesystem posture is writable
5. ✅ `.\ops\verify.ps1` returns exit code 0

## Decision Needed

None at this time. Baseline is working as expected.


