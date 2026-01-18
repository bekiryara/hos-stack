-- Messaging threads table
create table if not exists threads (
  id uuid primary key default gen_random_uuid(),
  context_type text not null,
  context_id text not null,
  created_at timestamptz not null default now(),
  unique (context_type, context_id)
);

create index if not exists idx_threads_context on threads (context_type, context_id);





