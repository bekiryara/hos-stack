-- 014_hos_oidc_tables_create.sql
-- Backfill migration: earlier OIDC migrations may have been empty but still marked applied.
-- This migration guarantees required OIDC tables exist.

create table if not exists hos_oidc_clients (
  id uuid primary key,
  client_id text unique not null,
  redirect_uris jsonb not null default '[]'::jsonb,
  allowed_worlds jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists hos_oidc_clients_client_id_idx
  on hos_oidc_clients (client_id);

create table if not exists hos_oidc_keys (
  id uuid primary key,
  kid text unique not null,
  alg text not null default 'RS256',
  public_jwk jsonb not null,
  private_pem text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists hos_oidc_keys_active_idx
  on hos_oidc_keys (is_active);

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






