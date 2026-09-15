-- DEFACT FACILE migration: 030_ai_usage
-- Per-call AI usage log (also an anti-abuse signal).


create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete set null,
  organization_id uuid references public.organizations(id) on delete set null,
  user_id uuid references public.users(id) on delete set null,
  action text not null,
  provider text not null,
  model text not null,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  credits_used integer not null default 0,
  estimated_cost numeric(12,6) not null default 0,
  status text not null default 'SUCCESS' check (status in ('SUCCESS', 'FAILED', 'REJECTED')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index ai_usage_user_created_idx on public.ai_usage(user_id, created_at);
create index ai_usage_org_created_idx on public.ai_usage(organization_id, created_at);
