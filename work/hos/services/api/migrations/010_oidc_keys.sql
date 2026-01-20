-- 010_oidc_keys.sql
-- OIDC signing keys for id_token (JWKS).

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












