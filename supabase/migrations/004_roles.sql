-- DEFACT FACILE migration: 004_roles
-- System roles (organization_id null) and custom per-organization roles.


create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_system_has_no_org check ((is_system and organization_id is null) or (not is_system and organization_id is not null))
);

create unique index roles_system_code_unique on public.roles(code) where organization_id is null;
create unique index roles_org_code_unique on public.roles(organization_id, code) where organization_id is not null;

create trigger set_roles_updated_at
  before update on public.roles
  for each row execute function public.set_updated_at();
