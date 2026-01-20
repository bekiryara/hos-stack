-- 008_hos_proofs.sql
-- Canonical proof store (minimal) to support GET /v1/proof and confirm finalization.
-- Safe: IF NOT EXISTS.

create table if not exists hos_proofs (
  proof_id uuid primary key,
  occurred_at timestamptz not null,
  world text not null,
  tenant_id uuid not null references tenants(id) on delete cascade,
  request_id uuid null,
  actor_id uuid null references users(id) on delete set null,
  kind text not null,
  subject_ref jsonb not null,
  payload jsonb not null,
  request_hash text not null,
  idempotency_key text null,
  hash text not null,
  created_at timestamptz not null default now()
);

-- Canonical idempotency: one proof per (tenant_id, world, kind, idempotency_key) when key present.
create unique index if not exists hos_proofs_idem_uq
  on hos_proofs(tenant_id, world, kind, idempotency_key)
  where idempotency_key is not null;

-- Fallback idempotency: one proof per (tenant_id, world, kind, request_hash).
create unique index if not exists hos_proofs_request_hash_uq
  on hos_proofs(tenant_id, world, kind, request_hash);

create index if not exists hos_proofs_query_idx
  on hos_proofs(tenant_id, world, occurred_at desc);

