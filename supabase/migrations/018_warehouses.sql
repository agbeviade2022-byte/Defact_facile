-- DEFACT FACILE migration: warehouses
-- Physical/logical stock locations.

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint warehouses_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  store_id uuid,
  name text not null,
  code text,
  address text,
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index warehouses_personal_workspace_idx on public.warehouses(personal_workspace_id) where personal_workspace_id is not null;
create index warehouses_organization_idx on public.warehouses(organization_id) where organization_id is not null;

create trigger set_warehouses_updated_at
  before update on public.warehouses
  for each row execute function public.set_updated_at();
