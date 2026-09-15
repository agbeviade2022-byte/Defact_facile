-- DEFACT FACILE migration: invoices
-- Invoices. Never hard-deleted: use CANCELLED / VOID / ARCHIVED with audit.

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint invoices_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  customer_id uuid references public.customers(id) on delete set null,
  quote_id uuid references public.quotes(id) on delete set null,
  sale_id uuid,
  number text not null,
  kind text not null default 'INVOICE' check (kind in ('INVOICE', 'PROFORMA', 'CREDIT_NOTE')),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'SENT', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED', 'VOID', 'ARCHIVED')),
  issue_date date not null default current_date,
  due_date date,
  currency char(3) not null default 'XOF',
  subtotal numeric(14,2) not null default 0,
  discount_type text not null default 'NONE' check (discount_type in ('NONE', 'PERCENT', 'AMOUNT')),
  discount_value numeric(14,2) not null default 0 check (discount_value >= 0),
  discount_amount numeric(14,2) not null default 0,
  tax_amount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  amount_paid numeric(14,2) not null default 0 check (amount_paid >= 0),
  amount_due numeric(14,2) not null default 0,
  notes text,
  terms text,
  sent_at timestamptz,
  paid_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  fne_status text not null default 'NOT_SUBMITTED' check (fne_status in ('NOT_SUBMITTED', 'PENDING', 'ACCEPTED', 'REJECTED')),
  fne_reference text,
  fne_payload jsonb,
  ai_generated boolean not null default false,
  version integer not null default 1,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index invoices_personal_workspace_idx on public.invoices(personal_workspace_id) where personal_workspace_id is not null;
create index invoices_organization_idx on public.invoices(organization_id) where organization_id is not null;

create trigger set_invoices_updated_at
  before update on public.invoices
  for each row execute function public.set_updated_at();

create unique index invoices_number_per_org on public.invoices(organization_id, number) where organization_id is not null;
create unique index invoices_number_per_ws on public.invoices(personal_workspace_id, number) where personal_workspace_id is not null;
create index invoices_customer_idx on public.invoices(customer_id);
create index invoices_status_due_idx on public.invoices(status, due_date);

alter table public.quotes
  add constraint quotes_converted_invoice_fk
  foreign key (converted_invoice_id) references public.invoices(id) on delete set null;
