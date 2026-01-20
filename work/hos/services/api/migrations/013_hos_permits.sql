-- 013_hos_permits.sql
-- Canonical PERMIT issuance store (minimal) per FOUNDING_SPEC.
-- Safe: IF NOT EXISTS.

create table if not exists hos_permits (
  permit_id uuid primary key,
  actor_id uuid not null references users(id) on delete restrict,
  tenant_id uuid not null references tenants(id) on delete cascade,
  command_key text not null,
  world text not null,
  subject_ref jsonb not null,
  from_status text null,
  to_status text not null,
  expected_version text null,
  snapshot jsonb not null,
  snapshot_hash text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

-- Issuance idempotency: UNIQUE(actor_id, tenant_id, command_key)
create unique index if not exists hos_permits_actor_tenant_command_uq
  on hos_permits(actor_id, tenant_id, command_key);

create index if not exists hos_permits_expires_at_idx
  on hos_permits(expires_at);

create table if not exists hos_permit_confirms (
  permit_id uuid primary key references hos_permits(permit_id) on delete cascade,
  world_mutation_id uuid not null unique,
  proof_id uuid not null,
  snapshot_hash text not null,
  mutation_hash text not null,
  confirmed_at timestamptz not null,
  created_at timestamptz not null default now()
);








