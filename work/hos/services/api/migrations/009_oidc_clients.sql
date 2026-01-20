-- 009_oidc_clients.sql
-- Minimal OIDC client registry for H-OS SSO.
-- Used by /authorize to validate client_id + redirect_uri.

create table if not exists hos_oidc_clients (
  id uuid primary key,
  client_id text unique not null,
  redirect_uris jsonb not null default '[]'::jsonb,
  allowed_worlds jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists hos_oidc_clients_client_id_idx
  on hos_oidc_clients (client_id);












