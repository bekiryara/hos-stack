# Repository Layout

Top-level structure:

- `work/hos` - H-OS services and related code
- `work/pazar` - Marketplace backend (Laravel)
- `work/marketplace-web` - Marketplace frontend
- `ops` - Operational scripts, checks, gates, tooling
- `docs` - Canonical documentation and runbooks
- `contracts` - Contract snapshots and API contract assets

Operational subfolders:

- `ops/_checks` - deterministic gate/check scripts
- `ops/_tools` - helper and utility scripts
- `ops/snapshots` - route/schema snapshots used by contract gates

Documentation entrypoints:

- `docs/CURRENT.md`
- `docs/RULES.md`
- `docs/WP_CLOSEOUTS.md`
- `docs/PROOFS/PASS_LOG.md`
- `docs/runbooks/OPS_ENTRYPOINTS.md`

