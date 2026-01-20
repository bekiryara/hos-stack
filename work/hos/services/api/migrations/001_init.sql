-- 001_init.sql
-- Initial schema for H-OS API.
-- This migration is written to be safe against repeated execution (IF NOT EXISTS),
-- but it is tracked via schema_migrations and should run only once per DB.

create table if not exists tenants (
  id uuid primary key,
  slug text unique not null,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists users (
  id uuid primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  email text not null,
  password_hash text not null,
  created_at timestamptz not null default now(),
  unique(tenant_id, email)
);

create table if not exists audit_events (
  id uuid primary key,
  tenant_id uuid null references tenants(id) on delete set null,
  actor_user_id uuid null references users(id) on delete set null,
  action text not null,
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);




