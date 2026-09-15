-- DEFACT FACILE migration: customers
-- Customers scoped to a workspace.

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint customers_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  type text not null default 'INDIVIDUAL' check (type in ('INDIVIDUAL', 'COMPANY')),
  name text not null,
  legal_name text,
  email citext,
  phone text,
  whatsapp_phone text,
  address text,
  city text,
  country_code char(2) default 'CI',
  ncc text,
  rccm text,
  notes text,
  tags text[] not null default '{}',
  is_archived boolean not null default false,
  external_ref text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index customers_personal_workspace_idx on public.customers(personal_workspace_id) where personal_workspace_id is not null;
create index customers_organization_idx on public.customers(organization_id) where organization_id is not null;

create trigger set_customers_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

create index customers_name_trgm_idx on public.customers using gin (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(phone, '')));
