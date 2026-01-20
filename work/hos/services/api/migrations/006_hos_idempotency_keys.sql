-- 006_hos_idempotency_keys.sql
-- Idempotency store for permit/confirm/proof and other canonical endpoints.
-- Safe: IF NOT EXISTS.

create table if not exists hos_idempotency_keys (
  id uuid primary key,
  key text not null,
  scope text not null,
  tenant_id text null,
  status text not null default 'processing',
  request_hash text not null,
  response_json jsonb null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists hos_idempotency_keys_key_uq on hos_idempotency_keys (key);
create index if not exists hos_idempotency_keys_expires_at_idx on hos_idempotency_keys (expires_at);

