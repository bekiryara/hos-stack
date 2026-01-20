-- Messaging messages table
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references threads(id) on delete cascade,
  sender_type text not null,
  sender_id text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_thread on messages (thread_id, created_at desc);

