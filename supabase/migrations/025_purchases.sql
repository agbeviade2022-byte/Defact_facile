-- DEFACT FACILE migration: purchases
-- Purchase orders.

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint purchases_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  supplier_id uuid references public.suppliers(id) on delete set null,
  warehouse_id uuid references public.warehouses(id) on delete set null,
  number text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'ORDERED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED')),
  ordered_at date,
  expected_at date,
  received_at timestamptz,
  currency char(3) not null default 'XOF',
  subtotal numeric(14,2) not null default 0,
  discount_type text not null default 'NONE' check (discount_type in ('NONE', 'PERCENT', 'AMOUNT')),
  discount_value numeric(14,2) not null default 0 check (discount_value >= 0),
  discount_amount numeric(14,2) not null default 0,
  tax_amount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  amount_paid numeric(14,2) not null default 0,
  notes text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index purchases_personal_workspace_idx on public.purchases(personal_workspace_id) where personal_workspace_id is not null;
create index purchases_organization_idx on public.purchases(organization_id) where organization_id is not null;

create trigger set_purchases_updated_at
  before update on public.purchases
  for each row execute function public.set_updated_at();

create unique index purchases_number_per_org on public.purchases(organization_id, number) where organization_id is not null;
create unique index purchases_number_per_ws on public.purchases(personal_workspace_id, number) where personal_workspace_id is not null;
