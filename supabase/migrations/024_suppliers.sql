-- DEFACT FACILE migration: suppliers
-- Suppliers.

create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint suppliers_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  name text not null,
  contact_name text,
  email citext,
  phone text,
  address text,
  city text,
  country_code char(2) default 'CI',
  ncc text,
  notes text,
  is_archived boolean not null default false,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index suppliers_personal_workspace_idx on public.suppliers(personal_workspace_id) where personal_workspace_id is not null;
create index suppliers_organization_idx on public.suppliers(organization_id) where organization_id is not null;

create trigger set_suppliers_updated_at
  before update on public.suppliers
  for each row execute function public.set_updated_at();
