# ops/ (What to run)

If you run **three** commands (most critical, fastest signal):

- `.\ops\openapi_contract.ps1`
- `.\ops\conformance.ps1`
- `.\ops\pazar_spine_check.ps1`

Single local pack (recommended):

- `.\ops\full_gates.ps1` (verify + openapi + conformance + pazar spine + messaging)

Human-friendly entrypoint (recommended):

- `.\ops\ops.ps1 full|status|run|verify|openapi|conformance|pazar-spine|messaging`

Dashboard / deeper packs:

- `.\ops\ops_status.ps1` (run with `-Ci` to enable optional/deep checks)
- `docs/ops/OPS_ENTRYPOINTS.md` (canonical entrypoint index)
- `ops/INDEX.md` (catalog: what exists + CI vs entrypoints)

Notes:

- Scripts labelled **Historical/retired** are compatibility wrappers; prefer the canonical scripts above.
- Scripts with **proof/prototype** in the name are one-off verification helpers (not daily CI gates).

## ops/_extras (non-core, grouped)

These scripts are intentionally grouped under `ops/_extras/` to reduce `ops/` root noise.
Old paths are kept as thin wrappers for compatibility (optional).

- **`ops/_extras/proofs/`**: one-off proof scripts (evidence / demos)
- **`ops/_extras/prototype/`**: prototype/demo helpers (seed, readiness)
- **`ops/_extras/tools/`**: interactive tools (menus)
- **`ops/_extras/maintenance/`**: one-time maintenance/freeze scripts
- **`ops/_extras/packs/`**: local packs (dev convenience)

