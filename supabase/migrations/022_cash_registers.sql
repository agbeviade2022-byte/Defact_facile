-- DEFACT FACILE migration: cash_registers
-- Cash registers per store.

create table public.cash_registers (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint cash_registers_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  store_id uuid references public.stores(id) on delete set null,
  name text not null,
  currency char(3) not null default 'XOF',
  opening_balance numeric(14,2) not null default 0,
  current_balance numeric(14,2) not null default 0,
  status text not null default 'OPEN' check (status in ('OPEN', 'CLOSED')),
  opened_at timestamptz,
  closed_at timestamptz,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index cash_registers_personal_workspace_idx on public.cash_registers(personal_workspace_id) where personal_workspace_id is not null;
create index cash_registers_organization_idx on public.cash_registers(organization_id) where organization_id is not null;

create trigger set_cash_registers_updated_at
  before update on public.cash_registers
  for each row execute function public.set_updated_at();

alter table public.sales add constraint sales_cash_register_fk foreign key (cash_register_id) references public.cash_registers(id) on delete set null;
