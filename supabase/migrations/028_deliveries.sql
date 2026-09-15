-- DEFACT FACILE migration: deliveries
-- Deliveries.

create table public.deliveries (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint deliveries_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  sale_id uuid references public.sales(id) on delete set null,
  invoice_id uuid references public.invoices(id) on delete set null,
  customer_id uuid references public.customers(id) on delete set null,
  assigned_to uuid references public.users(id) on delete set null,
  status text not null default 'PREPARING' check (status in ('PREPARING', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'RETURNED')),
  address text,
  city text,
  phone text,
  scheduled_at timestamptz,
  delivered_at timestamptz,
  notes text,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index deliveries_personal_workspace_idx on public.deliveries(personal_workspace_id) where personal_workspace_id is not null;
create index deliveries_organization_idx on public.deliveries(organization_id) where organization_id is not null;

create trigger set_deliveries_updated_at
  before update on public.deliveries
  for each row execute function public.set_updated_at();
