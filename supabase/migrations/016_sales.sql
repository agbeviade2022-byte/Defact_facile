-- DEFACT FACILE migration: sales
-- Quick point-of-sale transactions.

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint sales_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  customer_id uuid references public.customers(id) on delete set null,
  store_id uuid,
  warehouse_id uuid,
  cash_register_id uuid,
  number text not null,
  status text not null default 'COMPLETED' check (status in ('DRAFT', 'COMPLETED', 'CANCELLED', 'REFUNDED')),
  sold_at timestamptz not null default now(),
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

create index sales_personal_workspace_idx on public.sales(personal_workspace_id) where personal_workspace_id is not null;
create index sales_organization_idx on public.sales(organization_id) where organization_id is not null;

create trigger set_sales_updated_at
  before update on public.sales
  for each row execute function public.set_updated_at();

create unique index sales_number_per_org on public.sales(organization_id, number) where organization_id is not null;
create unique index sales_number_per_ws on public.sales(personal_workspace_id, number) where personal_workspace_id is not null;

alter table public.invoices add constraint invoices_sale_fk foreign key (sale_id) references public.sales(id) on delete set null;
alter table public.payments add constraint payments_sale_fk foreign key (sale_id) references public.sales(id) on delete set null;
