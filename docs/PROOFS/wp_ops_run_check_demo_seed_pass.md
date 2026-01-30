# WP-NEXT: ops_run — CheckDemoSeed PASS

**Timestamp:** 2026-01-30 (local gate run)  
**Scope:** Ops + docs only. No frontend/backend code changes.

## Summary

- **ops_run.ps1:** Added `[switch]$CheckDemoSeed`; when `-Profile Prototype` and `-CheckDemoSeed` are set, forwards to `prototype_v1.ps1 -CheckDemoSeed`. Default (parametresiz) behaviour unchanged.
- **Outcome:** ops_run Prototype artık -CheckDemoSeed ile demo seed doğruluyor (fast debug, no drift).
- **INFO:** When `-CheckDemoSeed` is set, script prints "INFO: Demo seed check ENABLED".

## Gate commands (PASS evidence)

```
.\ops\run_wp_next_local_gates.ps1
=== WP-NEXT LOCAL GATES: PASS ===

.\ops\ops_run.ps1 -Profile Prototype -CheckDemoSeed
INFO: Demo seed check ENABLED
[3] Checking seed (non-destructive)...
PASS: Seed check (2 seed listings found)
...
OVERALL STATUS: PASS
All checks passed.
```

## Files changed

1. `ops/ops_run.ps1` — param CheckDemoSeed, forward to prototype_v1, INFO line
2. `docs/PROOFS/wp_ops_run_check_demo_seed_pass.md`
3. `docs/WP_CLOSEOUTS.md` — new entry
