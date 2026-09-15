-- DEFACT FACILE migration: 007_organization_members
-- Membership binds a user to an organization with one role.


create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete restrict,
  status text not null default 'ACTIVE' check (status in ('INVITED', 'ACTIVE', 'SUSPENDED', 'REMOVED')),
  invited_email citext,
  invited_by uuid references public.users(id) on delete set null,
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index organization_members_user_idx on public.organization_members(user_id);

create trigger set_organization_members_updated_at
  before update on public.organization_members
  for each row execute function public.set_updated_at();

-- Helper used by RLS policies: does the current JWT user belong to this organization?
create or replace function public.is_org_member(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = org
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
  );
$$;

create or replace function public.owns_personal_workspace(ws uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.personal_workspaces w
    where w.id = ws and w.user_id = auth.uid()
  );
$$;

-- Generic tenant check reused by every business table policy.
create or replace function public.can_access_tenant(ws uuid, org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select (ws is not null and public.owns_personal_workspace(ws))
      or (org is not null and public.is_org_member(org));
$$;
