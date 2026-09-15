-- DEFACT FACILE migration: stores
-- Points of sale / shops.

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint stores_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  name text not null,
  code text,
  address text,
  city text,
  phone text,
  is_active boolean not null default true,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index stores_personal_workspace_idx on public.stores(personal_workspace_id) where personal_workspace_id is not null;
create index stores_organization_idx on public.stores(organization_id) where organization_id is not null;

create trigger set_stores_updated_at
  before update on public.stores
  for each row execute function public.set_updated_at();

alter table public.warehouses add constraint warehouses_store_fk foreign key (store_id) references public.stores(id) on delete set null;
alter table public.sales add constraint sales_store_fk foreign key (store_id) references public.stores(id) on delete set null;
alter table public.sales add constraint sales_warehouse_fk foreign key (warehouse_id) references public.warehouses(id) on delete set null;
