-- DEFACT FACILE migration: 032_anti_abuse_events
-- Suspicious behaviour signals and decisions.


create table public.anti_abuse_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  installation_id text,
  ip inet,
  event_type text not null,
  severity text not null default 'LOW' check (severity in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  score integer not null default 0,
  decision text not null default 'NONE' check (decision in ('NONE', 'FLAG', 'THROTTLE', 'BLOCK', 'REVIEW')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index anti_abuse_events_user_idx on public.anti_abuse_events(user_id, created_at);
