-- DEFACT FACILE migration: expenses
-- Business expenses.

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint expenses_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  category text not null,
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null default 'XOF',
  payment_method text check (payment_method in ('CASH', 'ORANGE_MONEY', 'MTN_MOMO', 'MOOV_MONEY', 'WAVE', 'BANK_TRANSFER', 'CARD', 'OTHER')),
  spent_at date not null default current_date,
  supplier_id uuid references public.suppliers(id) on delete set null,
  cash_register_id uuid references public.cash_registers(id) on delete set null,
  description text,
  receipt_url text,
  status text not null default 'RECORDED' check (status in ('RECORDED', 'APPROVED', 'REJECTED', 'ARCHIVED')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index expenses_personal_workspace_idx on public.expenses(personal_workspace_id) where personal_workspace_id is not null;
create index expenses_organization_idx on public.expenses(organization_id) where organization_id is not null;

create trigger set_expenses_updated_at
  before update on public.expenses
  for each row execute function public.set_updated_at();

create index expenses_spent_at_idx on public.expenses(spent_at);
