# SRC - Repository Source Map (Entrypoints)

**Purpose:** Minimal “where to start” map for code + ops + proofs. Paths are relative to repo root.

---

## Backend Entrypoints

- `docker-compose.yml` - Main stack definition (what runs together).
- `work/hos/services/api/src/index.js` - H-OS API process entrypoint.
- `work/pazar/bootstrap/app.php` - Pazar (Laravel) application bootstrap.
- `work/pazar/routes/api.php` - Pazar API route registry entrypoint.
- `work/messaging/services/api/src/index.js` - Messaging API process entrypoint.

## Frontend Entrypoints

- `work/marketplace-web/src/main.js` - Marketplace Web app entrypoint.
- `work/marketplace-web/src/router.js` - Marketplace Web routes/guards.
- `work/hos/services/web/src/main.tsx` - H-OS Web UI entrypoint.
- `work/hos/services/web/src/ui/App.tsx` - H-OS Web root UI component.

## Ops Entrypoints

- `ops/ops_run.ps1` - Single daily ops entrypoint (Prototype/Full profiles).
- `.\ops\ops.ps1 verify` - Baseline health verification (no PASS, no next step).
- `.\ops\ops.ps1 conformance` - Architecture conformance gate (policy + drift rules).
- `ops/ops.ps1 ship` - Single publish path to main (gates + push).

## Catalog SSOT (External Dataset)

- **Dataset SSOT (source of change)**: `D:\stack-data\catalog-dataset\csv\`
- **Dataset tools (CSV → manifests artifact)**: `D:\stack-data\catalog-dataset\tools\`
- **Generated artifact (manifests root)**: `D:\stack-data\catalog-dataset\out\manifests_current\`
- **Importer entrypoint (inside Pazar/Laravel)**: `work/pazar/routes/console.php` (`catalog:import`, `catalog:sync`)

## Proof & Closeout Entrypoints

- `docs/PROOFS/PASS_LOG.md` - Single proof/evidence log (append-only) for work packages.
- `docs/WP_CLOSEOUTS.md` - Current WP closeouts (recent window).
- `docs/closeouts/` - Archived WP closeouts (older windows).
- `docs/RELEASES/` - Release-grade baseline artifacts (RCs and plans).

