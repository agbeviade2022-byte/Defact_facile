-- DEFACT FACILE migration: cash_transactions
-- Cash register ledger.

create table public.cash_transactions (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint cash_transactions_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  cash_register_id uuid not null references public.cash_registers(id) on delete restrict,
  type text not null check (type in ('SALE', 'PAYMENT_IN', 'PAYMENT_OUT', 'DEPOSIT', 'WITHDRAWAL', 'ADJUSTMENT', 'EXPENSE')),
  amount numeric(14,2) not null check (amount <> 0),
  reference_type text,
  reference_id uuid,
  notes text,
  occurred_at timestamptz not null default now(),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index cash_transactions_personal_workspace_idx on public.cash_transactions(personal_workspace_id) where personal_workspace_id is not null;
create index cash_transactions_organization_idx on public.cash_transactions(organization_id) where organization_id is not null;

create trigger set_cash_transactions_updated_at
  before update on public.cash_transactions
  for each row execute function public.set_updated_at();

create index cash_transactions_register_idx on public.cash_transactions(cash_register_id, occurred_at);
