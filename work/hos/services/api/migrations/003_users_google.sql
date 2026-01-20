-- 003_users_google.sql
-- Add optional Google OIDC subject linkage to users.

alter table users
  add column if not exists google_sub text;

-- Uniqueness within tenant (only when google_sub is present)
create unique index if not exists users_tenant_google_sub_uniq
  on users (tenant_id, google_sub)
  where google_sub is not null;



