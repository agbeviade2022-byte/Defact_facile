-- DEFACT FACILE migration: quotes
-- Quotes (devis). Totals are computed server-side, never by the client or an LLM.

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint quotes_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  customer_id uuid references public.customers(id) on delete set null,
  number text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED')),
  issue_date date not null default current_date,
  valid_until date,
  currency char(3) not null default 'XOF',
  subtotal numeric(14,2) not null default 0,
  discount_type text not null default 'NONE' check (discount_type in ('NONE', 'PERCENT', 'AMOUNT')),
  discount_value numeric(14,2) not null default 0 check (discount_value >= 0),
  discount_amount numeric(14,2) not null default 0,
  tax_amount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,
  notes text,
  terms text,
  sent_at timestamptz,
  accepted_at timestamptz,
  rejected_at timestamptz,
  cancelled_at timestamptz,
  converted_invoice_id uuid,
  ai_generated boolean not null default false,
  version integer not null default 1,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index quotes_personal_workspace_idx on public.quotes(personal_workspace_id) where personal_workspace_id is not null;
create index quotes_organization_idx on public.quotes(organization_id) where organization_id is not null;

create trigger set_quotes_updated_at
  before update on public.quotes
  for each row execute function public.set_updated_at();

create or replace function public.forbid_hard_delete()
returns trigger language plpgsql as $$
begin
  raise exception '% rows are never hard-deleted; use a status transition (CANCELLED/VOID/ARCHIVED)', tg_table_name;
end;
$$;

-- Financial documents are never physically deleted (even by the service role):
-- use status transitions (CANCELLED / VOID / ARCHIVED) with audit instead.
create trigger quotes_no_hard_delete
  before delete on public.quotes
  for each row execute function public.forbid_hard_delete();

create unique index quotes_number_per_org on public.quotes(organization_id, number) where organization_id is not null;
create unique index quotes_number_per_ws on public.quotes(personal_workspace_id, number) where personal_workspace_id is not null;
create index quotes_customer_idx on public.quotes(customer_id);
create index quotes_status_idx on public.quotes(status);
