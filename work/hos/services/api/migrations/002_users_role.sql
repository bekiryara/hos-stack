-- 002_users_role.sql
-- Add basic role support for tenant-scoped authorization.

alter table users
  add column if not exists role text not null default 'member';




