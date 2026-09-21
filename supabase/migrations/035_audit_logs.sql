-- DEFACT FACILE migration: 035_audit_logs
-- Append-only audit trail for sensitive operations.


create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete set null,
  organization_id uuid references public.organizations(id) on delete set null,
  actor_id uuid references public.users(id) on delete set null,
  actor_type text not null default 'USER' check (actor_type in ('USER', 'SYSTEM', 'AI')),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create index audit_logs_org_created_idx on public.audit_logs(organization_id, created_at desc);
create index audit_logs_ws_created_idx on public.audit_logs(personal_workspace_id, created_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);

create trigger audit_logs_immutable
  before update or delete on public.audit_logs
  for each row execute function public.forbid_mutation();
