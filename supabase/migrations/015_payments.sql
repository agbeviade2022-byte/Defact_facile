-- DEFACT FACILE migration: payments
-- Payments (full or partial) against invoices or sales.

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint payments_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  invoice_id uuid references public.invoices(id) on delete set null,
  sale_id uuid,
  customer_id uuid references public.customers(id) on delete set null,
  method text not null check (method in ('CASH', 'ORANGE_MONEY', 'MTN_MOMO', 'MOOV_MONEY', 'WAVE', 'BANK_TRANSFER', 'CARD', 'OTHER')),
  direction text not null default 'IN' check (direction in ('IN', 'REFUND')),
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null default 'XOF',
  paid_at timestamptz not null default now(),
  reference text,
  notes text,
  receipt_number text,
  status text not null default 'CONFIRMED' check (status in ('PENDING', 'CONFIRMED', 'FAILED', 'REVERSED')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index payments_personal_workspace_idx on public.payments(personal_workspace_id) where personal_workspace_id is not null;
create index payments_organization_idx on public.payments(organization_id) where organization_id is not null;

create trigger set_payments_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

create index payments_invoice_idx on public.payments(invoice_id);
create index payments_paid_at_idx on public.payments(paid_at);
