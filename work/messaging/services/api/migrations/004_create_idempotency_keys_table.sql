-- Idempotency keys table for WP-16
create table if not exists idempotency_keys (
  key_hash text primary key,
  resource_type text not null,
  resource_id text not null,
  request_hash text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_idempotency_keys_resource on idempotency_keys (resource_type, resource_id);


