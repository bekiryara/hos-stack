-- 015_wp8_memberships_table.sql
-- WP-8: Core Persona Switch + Membership Strict Mode
-- Non-breaking: adds memberships table, backfills from existing users table
-- Safe: IF NOT EXISTS, idempotent

-- Create memberships table (canonical model)
create table if not exists memberships (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null default 'member', -- owner|admin|member|staff
  status text not null default 'active', -- active|inactive|suspended
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(tenant_id, user_id)
);

create index if not exists memberships_tenant_id_idx on memberships(tenant_id);
create index if not exists memberships_user_id_idx on memberships(user_id);
create index if not exists memberships_status_idx on memberships(status);
create index if not exists memberships_tenant_user_active_idx on memberships(tenant_id, user_id, status) where status = 'active';

-- Backfill: Create memberships from existing users
-- For each user, create a membership with role from users.role (or 'owner' if null and first user in tenant)
insert into memberships (tenant_id, user_id, role, status, created_at, updated_at)
select 
  u.tenant_id,
  u.id as user_id,
  coalesce(u.role, 
    case 
      when (select count(*) from users u2 where u2.tenant_id = u.tenant_id) = 1 then 'owner'
      else 'member'
    end
  ) as role,
  'active' as status,
  u.created_at,
  now() as updated_at
from users u
where not exists (
  select 1 from memberships m 
  where m.tenant_id = u.tenant_id and m.user_id = u.id
)
on conflict (tenant_id, user_id) do nothing;

-- Update tenants table: add status and created_by_user_id (non-breaking, nullable)
alter table tenants 
  add column if not exists status text default 'active',
  add column if not exists created_by_user_id uuid references users(id) on delete set null,
  add column if not exists display_name text;

-- Set display_name = name if display_name is null (backfill)
update tenants set display_name = name where display_name is null or display_name = '';

-- Update users table: add display_name (non-breaking, nullable)
alter table users 
  add column if not exists display_name text;

-- Set display_name = email prefix if display_name is null (backfill)
update users set display_name = split_part(email, '@', 1) where display_name is null or display_name = '';


