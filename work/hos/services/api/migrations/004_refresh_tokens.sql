-- 004_refresh_tokens.sql
-- Refresh tokens for long-lived sessions (store only hashes).

create table if not exists refresh_tokens (
  id uuid primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  token_hash text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz null,
  rotated_from uuid null references refresh_tokens(id) on delete set null
);

create unique index if not exists refresh_tokens_token_hash_uniq
  on refresh_tokens(token_hash);

create index if not exists refresh_tokens_lookup_idx
  on refresh_tokens(tenant_id, user_id, expires_at)
  where revoked_at is null;



