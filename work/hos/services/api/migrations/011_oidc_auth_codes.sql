-- 011_oidc_auth_codes.sql
-- Authorization codes for OIDC Authorization Code + PKCE.

create table if not exists hos_oidc_auth_codes (
  code text primary key,
  client_id text not null,
  redirect_uri text not null,
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  scope text not null,
  world text not null,
  code_challenge text not null,
  code_challenge_method text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists hos_oidc_auth_codes_expires_idx
  on hos_oidc_auth_codes (expires_at);












