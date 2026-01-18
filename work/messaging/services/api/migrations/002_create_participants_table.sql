-- Messaging participants table
create table if not exists participants (
  thread_id uuid not null references threads(id) on delete cascade,
  participant_type text not null,
  participant_id text not null,
  joined_at timestamptz not null default now(),
  unique (thread_id, participant_type, participant_id)
);

create index if not exists idx_participants_thread on participants (thread_id);





