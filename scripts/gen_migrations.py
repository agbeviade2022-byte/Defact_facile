#!/usr/bin/env python3
"""One-off helper used to author the initial Supabase migrations.

Kept in the repo so the shared SQL fragments (tenant columns, updated_at
triggers) stay consistent if a migration has to be regenerated. Existing
files are never overwritten unless --force is passed.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "supabase" / "migrations"

HEADER = "-- DEFACT FACILE migration: {name}\n-- {desc}\n\n"

# Every business table is owned by exactly one workspace: either a personal
# workspace or an organization. The check constraint enforces XOR.
TENANT = """  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint {t}_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),"""

AUDIT_COLS = """  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()"""

UPDATED_AT = """
create trigger set_{t}_updated_at
  before update on public.{t}
  for each row execute function public.set_updated_at();
"""

TENANT_INDEX = """
create index {t}_personal_workspace_idx on public.{t}(personal_workspace_id) where personal_workspace_id is not null;
create index {t}_organization_idx on public.{t}(organization_id) where organization_id is not null;
"""


NO_HARD_DELETE = """
-- Financial documents are never physically deleted (even by the service role):
-- use status transitions (CANCELLED / VOID / ARCHIVED) with audit instead.
create trigger {t}_no_hard_delete
  before delete on public.{t}
  for each row execute function public.forbid_hard_delete();
"""


def tenant_table(t: str, body: str, desc: str, extra: str = "") -> str:
    return (
        HEADER.format(name=f"{t}", desc=desc)
        + f"create table public.{t} (\n  id uuid primary key default gen_random_uuid(),\n"
        + TENANT.format(t=t)
        + "\n"
        + body.rstrip().rstrip(",")
        + ",\n"
        + AUDIT_COLS
        + "\n);\n"
        + TENANT_INDEX.format(t=t)
        + UPDATED_AT.format(t=t)
        + extra
    )


MIGRATIONS: dict[str, str] = {}

MIGRATIONS["001_users.sql"] = HEADER.format(name="001_users", desc="Global identity mirrored from auth.users + shared helpers.") + """
create extension if not exists "pgcrypto";
create extension if not exists "citext";

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- One account per human. Profile data lives here; credentials live in auth.users.
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext unique,
  phone text,
  full_name text,
  avatar_url text,
  locale text not null default 'fr',
  timezone text not null default 'Africa/Abidjan',
  last_active_workspace_kind text check (last_active_workspace_kind in ('personal', 'organization')),
  last_active_workspace_id uuid,
  is_platform_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

-- Platform admin flag is only ever changed by trusted server code (service role).
create or replace function public.protect_platform_admin_flag()
returns trigger language plpgsql as $$
begin
  if new.is_platform_admin is distinct from old.is_platform_admin
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'is_platform_admin can only be changed by the service role';
  end if;
  return new;
end;
$$;

create trigger users_protect_platform_admin
  before update on public.users
  for each row execute function public.protect_platform_admin_flag();

-- Auto-provision the profile row when Supabase Auth creates an account.
create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, email, phone, full_name, avatar_url)
  values (
    new.id,
    new.email,
    new.phone,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();
"""

MIGRATIONS["002_personal_workspaces.sql"] = HEADER.format(name="002_personal_workspaces", desc="Solo workspace owned by exactly one user.") + """
create table public.personal_workspaces (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  display_name text not null,
  legal_name text,
  phone text,
  email citext,
  address text,
  city text,
  country_code char(2) not null default 'CI',
  currency char(3) not null default 'XOF',
  ncc text,
  rccm text,
  tax_identifiers jsonb not null default '{}'::jsonb,
  logo_url text,
  default_tax_rate numeric(5,2) not null default 0,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_personal_workspaces_updated_at
  before update on public.personal_workspaces
  for each row execute function public.set_updated_at();
"""

MIGRATIONS["003_organizations.sql"] = HEADER.format(name="003_organizations", desc="Multi-user tenant (company).") + """
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  slug citext not null unique,
  name text not null,
  legal_name text,
  phone text,
  email citext,
  address text,
  city text,
  country_code char(2) not null default 'CI',
  currency char(3) not null default 'XOF',
  ncc text,
  rccm text,
  tax_identifiers jsonb not null default '{}'::jsonb,
  logo_url text,
  default_tax_rate numeric(5,2) not null default 0,
  settings jsonb not null default '{}'::jsonb,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'SUSPENDED', 'ARCHIVED')),
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_organizations_updated_at
  before update on public.organizations
  for each row execute function public.set_updated_at();
"""

MIGRATIONS["004_roles.sql"] = HEADER.format(name="004_roles", desc="System roles (organization_id null) and custom per-organization roles.") + """
create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_system_has_no_org check ((is_system and organization_id is null) or (not is_system and organization_id is not null))
);

create unique index roles_system_code_unique on public.roles(code) where organization_id is null;
create unique index roles_org_code_unique on public.roles(organization_id, code) where organization_id is not null;

create trigger set_roles_updated_at
  before update on public.roles
  for each row execute function public.set_updated_at();
"""

MIGRATIONS["005_permissions.sql"] = HEADER.format(name="005_permissions", desc="Granular permission catalogue (resource.action).") + """
create table public.permissions (
  code text primary key,
  resource text not null,
  action text not null,
  description text,
  constraint permissions_code_format check (code = resource || '.' || action)
);
"""

MIGRATIONS["006_role_permissions.sql"] = HEADER.format(name="006_role_permissions", desc="Role -> permission mapping.") + """
create table public.role_permissions (
  role_id uuid not null references public.roles(id) on delete cascade,
  permission_code text not null references public.permissions(code) on delete cascade,
  primary key (role_id, permission_code)
);
"""

MIGRATIONS["007_organization_members.sql"] = HEADER.format(name="007_organization_members", desc="Membership binds a user to an organization with one role.") + """
create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role_id uuid not null references public.roles(id) on delete restrict,
  status text not null default 'ACTIVE' check (status in ('INVITED', 'ACTIVE', 'SUSPENDED', 'REMOVED')),
  invited_email citext,
  invited_by uuid references public.users(id) on delete set null,
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create index organization_members_user_idx on public.organization_members(user_id);

create trigger set_organization_members_updated_at
  before update on public.organization_members
  for each row execute function public.set_updated_at();

-- A membership may only use a system role or a custom role of the same organization.
create or replace function public.check_member_role_scope()
returns trigger language plpgsql as $$
declare
  role_org uuid;
  role_is_system boolean;
begin
  select organization_id, is_system into role_org, role_is_system
    from public.roles where id = new.role_id;
  if role_is_system is distinct from true and role_org is distinct from new.organization_id then
    raise exception 'role % does not belong to organization %', new.role_id, new.organization_id;
  end if;
  return new;
end;
$$;

create trigger organization_members_role_scope
  before insert or update of role_id, organization_id on public.organization_members
  for each row execute function public.check_member_role_scope();

-- Helper used by RLS policies: does the current JWT user belong to this organization?
create or replace function public.is_org_member(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = org
      and m.user_id = auth.uid()
      and m.status = 'ACTIVE'
  );
$$;

create or replace function public.owns_personal_workspace(ws uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.personal_workspaces w
    where w.id = ws and w.user_id = auth.uid()
  );
$$;

-- Generic tenant check reused by every business table policy.
create or replace function public.can_access_tenant(ws uuid, org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select (ws is not null and public.owns_personal_workspace(ws))
      or (org is not null and public.is_org_member(org));
$$;
"""

MIGRATIONS["008_customers.sql"] = tenant_table(
    "customers",
    """  type text not null default 'INDIVIDUAL' check (type in ('INDIVIDUAL', 'COMPANY')),
  name text not null,
  legal_name text,
  email citext,
  phone text,
  whatsapp_phone text,
  address text,
  city text,
  country_code char(2) default 'CI',
  ncc text,
  rccm text,
  notes text,
  tags text[] not null default '{}',
  is_archived boolean not null default false,
  external_ref text,""",
    "Customers scoped to a workspace.",
    "\ncreate index customers_name_trgm_idx on public.customers using gin (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(phone, '')));\n",
)

MIGRATIONS["009_product_categories.sql"] = tenant_table(
    "product_categories",
    """  name text not null,
  parent_id uuid references public.product_categories(id) on delete set null,
  position integer not null default 0,""",
    "Hierarchical product categories.",
)

MIGRATIONS["010_products.sql"] = tenant_table(
    "products",
    """  category_id uuid references public.product_categories(id) on delete set null,
  kind text not null default 'PRODUCT' check (kind in ('PRODUCT', 'SERVICE')),
  name text not null,
  description text,
  sku text,
  barcode text,
  unit text not null default 'unité',
  purchase_price numeric(14,2) not null default 0 check (purchase_price >= 0),
  sale_price numeric(14,2) not null default 0 check (sale_price >= 0),
  tax_rate numeric(5,2) not null default 0 check (tax_rate >= 0),
  currency char(3) not null default 'XOF',
  track_stock boolean not null default false,
  min_stock numeric(14,3) not null default 0,
  image_url text,
  is_active boolean not null default true,
  is_archived boolean not null default false,""",
    "Products and services.",
    """
create unique index products_sku_per_org on public.products(organization_id, sku) where organization_id is not null and sku is not null;
create unique index products_sku_per_ws on public.products(personal_workspace_id, sku) where personal_workspace_id is not null and sku is not null;
""",
)

DOC_MONEY = """  currency char(3) not null default 'XOF',
  subtotal numeric(14,2) not null default 0,
  discount_type text not null default 'NONE' check (discount_type in ('NONE', 'PERCENT', 'AMOUNT')),
  discount_value numeric(14,2) not null default 0 check (discount_value >= 0),
  discount_amount numeric(14,2) not null default 0,
  tax_amount numeric(14,2) not null default 0,
  total numeric(14,2) not null default 0,"""

MIGRATIONS["011_quotes.sql"] = tenant_table(
    "quotes",
    """  customer_id uuid references public.customers(id) on delete set null,
  number text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED')),
  issue_date date not null default current_date,
  valid_until date,
"""
    + DOC_MONEY
    + """
  notes text,
  terms text,
  sent_at timestamptz,
  accepted_at timestamptz,
  rejected_at timestamptz,
  cancelled_at timestamptz,
  converted_invoice_id uuid,
  ai_generated boolean not null default false,
  version integer not null default 1,""",
    "Quotes (devis). Totals are computed server-side, never by the client or an LLM.",
    """
create or replace function public.forbid_hard_delete()
returns trigger language plpgsql as $$
begin
  raise exception '% rows are never hard-deleted; use a status transition (CANCELLED/VOID/ARCHIVED)', tg_table_name;
end;
$$;
"""
    + NO_HARD_DELETE.format(t="quotes")
    + """
create unique index quotes_number_per_org on public.quotes(organization_id, number) where organization_id is not null;
create unique index quotes_number_per_ws on public.quotes(personal_workspace_id, number) where personal_workspace_id is not null;
create index quotes_customer_idx on public.quotes(customer_id);
create index quotes_status_idx on public.quotes(status);
""",
)

ITEM_COLS = """  product_id uuid references public.products(id) on delete set null,
  position integer not null default 0,
  description text not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit text,
  unit_price numeric(14,2) not null check (unit_price >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  tax_rate numeric(5,2) not null default 0 check (tax_rate >= 0),
  line_subtotal numeric(14,2) not null default 0,
  line_tax numeric(14,2) not null default 0,
  line_total numeric(14,2) not null default 0,
  created_at timestamptz not null default now()"""

MIGRATIONS["012_quote_items.sql"] = HEADER.format(name="012_quote_items", desc="Quote line items.") + f"""
create table public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
{ITEM_COLS}
);

create index quote_items_quote_idx on public.quote_items(quote_id);
"""

MIGRATIONS["013_invoices.sql"] = tenant_table(
    "invoices",
    """  customer_id uuid references public.customers(id) on delete set null,
  quote_id uuid references public.quotes(id) on delete set null,
  sale_id uuid,
  number text not null,
  kind text not null default 'INVOICE' check (kind in ('INVOICE', 'PROFORMA', 'CREDIT_NOTE')),
  status text not null default 'DRAFT' check (status in ('DRAFT', 'SENT', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED', 'VOID', 'ARCHIVED')),
  issue_date date not null default current_date,
  due_date date,
"""
    + DOC_MONEY
    + """
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
  version integer not null default 1,""",
    "Invoices. Never hard-deleted: use CANCELLED / VOID / ARCHIVED with audit.",
    """
create unique index invoices_number_per_org on public.invoices(organization_id, number) where organization_id is not null;
create unique index invoices_number_per_ws on public.invoices(personal_workspace_id, number) where personal_workspace_id is not null;
create index invoices_customer_idx on public.invoices(customer_id);
create index invoices_status_due_idx on public.invoices(status, due_date);

alter table public.quotes
  add constraint quotes_converted_invoice_fk
  foreign key (converted_invoice_id) references public.invoices(id) on delete set null;
"""
    + NO_HARD_DELETE.format(t="invoices"),
)

MIGRATIONS["014_invoice_items.sql"] = HEADER.format(name="014_invoice_items", desc="Invoice line items.") + f"""
create table public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
{ITEM_COLS}
);

create index invoice_items_invoice_idx on public.invoice_items(invoice_id);
"""

MIGRATIONS["015_payments.sql"] = tenant_table(
    "payments",
    """  invoice_id uuid references public.invoices(id) on delete set null,
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
  status text not null default 'CONFIRMED' check (status in ('PENDING', 'CONFIRMED', 'FAILED', 'REVERSED')),""",
    "Payments (full or partial) against invoices or sales.",
    """
create index payments_invoice_idx on public.payments(invoice_id);
create index payments_paid_at_idx on public.payments(paid_at);
""",
)

MIGRATIONS["016_sales.sql"] = tenant_table(
    "sales",
    """  customer_id uuid references public.customers(id) on delete set null,
  store_id uuid,
  warehouse_id uuid,
  cash_register_id uuid,
  number text not null,
  status text not null default 'COMPLETED' check (status in ('DRAFT', 'COMPLETED', 'CANCELLED', 'REFUNDED')),
  sold_at timestamptz not null default now(),
"""
    + DOC_MONEY
    + """
  amount_paid numeric(14,2) not null default 0,
  notes text,""",
    "Quick point-of-sale transactions.",
    """
create unique index sales_number_per_org on public.sales(organization_id, number) where organization_id is not null;
create unique index sales_number_per_ws on public.sales(personal_workspace_id, number) where personal_workspace_id is not null;

alter table public.invoices add constraint invoices_sale_fk foreign key (sale_id) references public.sales(id) on delete set null;
alter table public.payments add constraint payments_sale_fk foreign key (sale_id) references public.sales(id) on delete set null;
"""
    + NO_HARD_DELETE.format(t="sales"),
)

MIGRATIONS["017_sale_items.sql"] = HEADER.format(name="017_sale_items", desc="Sale line items.") + f"""
create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
{ITEM_COLS}
);

create index sale_items_sale_idx on public.sale_items(sale_id);
"""

MIGRATIONS["018_warehouses.sql"] = tenant_table(
    "warehouses",
    """  store_id uuid,
  name text not null,
  code text,
  address text,
  is_default boolean not null default false,
  is_active boolean not null default true,""",
    "Physical/logical stock locations.",
)

MIGRATIONS["019_stock_levels.sql"] = HEADER.format(name="019_stock_levels", desc="Materialised current quantity per product per warehouse. Derived from stock_movements.") + """
create table public.stock_levels (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  warehouse_id uuid not null references public.warehouses(id) on delete cascade,
  quantity numeric(14,3) not null default 0,
  reserved_quantity numeric(14,3) not null default 0,
  updated_at timestamptz not null default now(),
  unique (product_id, warehouse_id)
);

create index stock_levels_warehouse_idx on public.stock_levels(warehouse_id);
"""

MIGRATIONS["020_stock_movements.sql"] = tenant_table(
    "stock_movements",
    """  product_id uuid not null references public.products(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  type text not null check (type in ('PURCHASE', 'SALE', 'ADJUSTMENT', 'TRANSFER_IN', 'TRANSFER_OUT', 'RETURN')),
  quantity numeric(14,3) not null check (quantity <> 0),
  unit_cost numeric(14,2),
  reference_type text,
  reference_id uuid,
  transfer_group_id uuid,
  reason text,
  occurred_at timestamptz not null default now(),
  client_event_id uuid,""",
    "Append-only stock event log. Levels are recomputed from these events (offline-safe).",
    """
-- Offline clients generate their own event id; replays must be idempotent.
create unique index stock_movements_client_event_unique on public.stock_movements(client_event_id) where client_event_id is not null;
create index stock_movements_product_wh_idx on public.stock_movements(product_id, warehouse_id, occurred_at);

create or replace function public.apply_stock_movement()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.stock_levels (product_id, warehouse_id, quantity)
  values (new.product_id, new.warehouse_id, new.quantity)
  on conflict (product_id, warehouse_id)
  do update set quantity = public.stock_levels.quantity + excluded.quantity,
                updated_at = now();
  return new;
end;
$$;

create trigger stock_movements_apply
  after insert on public.stock_movements
  for each row execute function public.apply_stock_movement();

-- Movements are immutable events.
create or replace function public.forbid_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'stock_movements rows are immutable; insert a compensating movement instead';
end;
$$;

create trigger stock_movements_immutable
  before update or delete on public.stock_movements
  for each row execute function public.forbid_mutation();
""",
)

MIGRATIONS["021_stores.sql"] = tenant_table(
    "stores",
    """  name text not null,
  code text,
  address text,
  city text,
  phone text,
  is_active boolean not null default true,""",
    "Points of sale / shops.",
    """
alter table public.warehouses add constraint warehouses_store_fk foreign key (store_id) references public.stores(id) on delete set null;
alter table public.sales add constraint sales_store_fk foreign key (store_id) references public.stores(id) on delete set null;
alter table public.sales add constraint sales_warehouse_fk foreign key (warehouse_id) references public.warehouses(id) on delete set null;
""",
)

MIGRATIONS["022_cash_registers.sql"] = tenant_table(
    "cash_registers",
    """  store_id uuid references public.stores(id) on delete set null,
  name text not null,
  currency char(3) not null default 'XOF',
  opening_balance numeric(14,2) not null default 0,
  current_balance numeric(14,2) not null default 0,
  status text not null default 'OPEN' check (status in ('OPEN', 'CLOSED')),
  opened_at timestamptz,
  closed_at timestamptz,""",
    "Cash registers per store.",
    """
alter table public.sales add constraint sales_cash_register_fk foreign key (cash_register_id) references public.cash_registers(id) on delete set null;
""",
)

MIGRATIONS["023_cash_transactions.sql"] = tenant_table(
    "cash_transactions",
    """  cash_register_id uuid not null references public.cash_registers(id) on delete restrict,
  type text not null check (type in ('SALE', 'PAYMENT_IN', 'PAYMENT_OUT', 'DEPOSIT', 'WITHDRAWAL', 'ADJUSTMENT', 'EXPENSE')),
  amount numeric(14,2) not null check (amount <> 0),
  reference_type text,
  reference_id uuid,
  notes text,
  occurred_at timestamptz not null default now(),""",
    "Cash register ledger.",
    "\ncreate index cash_transactions_register_idx on public.cash_transactions(cash_register_id, occurred_at);\n",
)

MIGRATIONS["024_suppliers.sql"] = tenant_table(
    "suppliers",
    """  name text not null,
  contact_name text,
  email citext,
  phone text,
  address text,
  city text,
  country_code char(2) default 'CI',
  ncc text,
  notes text,
  is_archived boolean not null default false,""",
    "Suppliers.",
)

MIGRATIONS["025_purchases.sql"] = tenant_table(
    "purchases",
    """  supplier_id uuid references public.suppliers(id) on delete set null,
  warehouse_id uuid references public.warehouses(id) on delete set null,
  number text not null,
  status text not null default 'DRAFT' check (status in ('DRAFT', 'ORDERED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED')),
  ordered_at date,
  expected_at date,
  received_at timestamptz,
"""
    + DOC_MONEY
    + """
  amount_paid numeric(14,2) not null default 0,
  notes text,""",
    "Purchase orders.",
    """
create unique index purchases_number_per_org on public.purchases(organization_id, number) where organization_id is not null;
create unique index purchases_number_per_ws on public.purchases(personal_workspace_id, number) where personal_workspace_id is not null;
""",
)

MIGRATIONS["026_purchase_items.sql"] = HEADER.format(name="026_purchase_items", desc="Purchase order lines with received quantity tracking.") + f"""
create table public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  received_quantity numeric(14,3) not null default 0 check (received_quantity >= 0),
{ITEM_COLS}
);

create index purchase_items_purchase_idx on public.purchase_items(purchase_id);
"""

MIGRATIONS["027_expenses.sql"] = tenant_table(
    "expenses",
    """  category text not null,
  amount numeric(14,2) not null check (amount > 0),
  currency char(3) not null default 'XOF',
  payment_method text check (payment_method in ('CASH', 'ORANGE_MONEY', 'MTN_MOMO', 'MOOV_MONEY', 'WAVE', 'BANK_TRANSFER', 'CARD', 'OTHER')),
  spent_at date not null default current_date,
  supplier_id uuid references public.suppliers(id) on delete set null,
  cash_register_id uuid references public.cash_registers(id) on delete set null,
  description text,
  receipt_url text,
  status text not null default 'RECORDED' check (status in ('RECORDED', 'APPROVED', 'REJECTED', 'ARCHIVED')),""",
    "Business expenses.",
    "\ncreate index expenses_spent_at_idx on public.expenses(spent_at);\n",
)

MIGRATIONS["028_deliveries.sql"] = tenant_table(
    "deliveries",
    """  sale_id uuid references public.sales(id) on delete set null,
  invoice_id uuid references public.invoices(id) on delete set null,
  customer_id uuid references public.customers(id) on delete set null,
  assigned_to uuid references public.users(id) on delete set null,
  status text not null default 'PREPARING' check (status in ('PREPARING', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'RETURNED')),
  address text,
  city text,
  phone text,
  scheduled_at timestamptz,
  delivered_at timestamptz,
  notes text,""",
    "Deliveries.",
)

MIGRATIONS["029_ai_credits.sql"] = HEADER.format(name="029_ai_credits", desc="AI credit balances per workspace + configurable action costs.") + """
create table public.ai_credits (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  balance integer not null default 0 check (balance >= 0),
  monthly_allowance integer not null default 0,
  period_start date,
  period_end date,
  updated_at timestamptz not null default now(),
  constraint ai_credits_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  )
);

create unique index ai_credits_ws_unique on public.ai_credits(personal_workspace_id) where personal_workspace_id is not null;
create unique index ai_credits_org_unique on public.ai_credits(organization_id) where organization_id is not null;

-- Cost per AI action. Editable without redeploying.
create table public.ai_action_costs (
  action text primary key,
  credits integer not null check (credits >= 0),
  description text,
  updated_at timestamptz not null default now()
);
"""

MIGRATIONS["030_ai_usage.sql"] = HEADER.format(name="030_ai_usage", desc="Per-call AI usage log (also an anti-abuse signal).") + """
create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete set null,
  organization_id uuid references public.organizations(id) on delete set null,
  user_id uuid references public.users(id) on delete set null,
  action text not null,
  provider text not null,
  model text not null,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  credits_used integer not null default 0,
  estimated_cost numeric(12,6) not null default 0,
  status text not null default 'SUCCESS' check (status in ('SUCCESS', 'FAILED', 'REJECTED')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index ai_usage_user_created_idx on public.ai_usage(user_id, created_at);
create index ai_usage_org_created_idx on public.ai_usage(organization_id, created_at);
"""

MIGRATIONS["031_device_installations.sql"] = HEADER.format(name="031_device_installations", desc="App installations (anti-abuse signal, never the sole blocking criterion).") + """
create table public.device_installations (
  id uuid primary key default gen_random_uuid(),
  installation_id text not null unique,
  user_id uuid references public.users(id) on delete set null,
  platform text check (platform in ('android', 'ios', 'web')),
  app_version text,
  device_model text,
  os_version text,
  first_ip inet,
  last_ip inet,
  push_token text,
  trial_started_at timestamptz,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index device_installations_user_idx on public.device_installations(user_id);
"""

MIGRATIONS["032_anti_abuse_events.sql"] = HEADER.format(name="032_anti_abuse_events", desc="Suspicious behaviour signals and decisions.") + """
create table public.anti_abuse_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.users(id) on delete set null,
  installation_id text,
  ip inet,
  event_type text not null,
  severity text not null default 'LOW' check (severity in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  score integer not null default 0,
  decision text not null default 'NONE' check (decision in ('NONE', 'FLAG', 'THROTTLE', 'BLOCK', 'REVIEW')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index anti_abuse_events_user_idx on public.anti_abuse_events(user_id, created_at);
"""

MIGRATIONS["033_plans.sql"] = HEADER.format(name="033_plans", desc="Subscription plans.") + """
create table public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  audience text not null default 'BOTH' check (audience in ('PERSONAL', 'ORGANIZATION', 'BOTH')),
  price_monthly numeric(12,2) not null default 0,
  price_yearly numeric(12,2) not null default 0,
  currency char(3) not null default 'XOF',
  ai_credits_monthly integer not null default 0,
  limits jsonb not null default '{}'::jsonb,
  features jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_plans_updated_at
  before update on public.plans
  for each row execute function public.set_updated_at();
"""

MIGRATIONS["034_subscriptions.sql"] = HEADER.format(name="034_subscriptions", desc="Workspace subscription state.") + """
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  plan_id uuid not null references public.plans(id) on delete restrict,
  status text not null default 'TRIALING' check (status in ('TRIALING', 'ACTIVE', 'PAST_DUE', 'CANCELLED', 'EXPIRED')),
  billing_cycle text not null default 'MONTHLY' check (billing_cycle in ('MONTHLY', 'YEARLY')),
  trial_ends_at timestamptz,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancelled_at timestamptz,
  payment_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscriptions_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  )
);

create unique index subscriptions_ws_unique on public.subscriptions(personal_workspace_id) where personal_workspace_id is not null;
create unique index subscriptions_org_unique on public.subscriptions(organization_id) where organization_id is not null;

create trigger set_subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();
"""

MIGRATIONS["035_audit_logs.sql"] = HEADER.format(name="035_audit_logs", desc="Append-only audit trail for sensitive operations.") + """
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete set null,
  organization_id uuid references public.organizations(id) on delete set null,
  actor_id uuid references public.users(id) on delete set null,
  actor_type text not null default 'USER' check (actor_type in ('USER', 'SYSTEM', 'AI')),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  ip inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create index audit_logs_org_created_idx on public.audit_logs(organization_id, created_at desc);
create index audit_logs_ws_created_idx on public.audit_logs(personal_workspace_id, created_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id);

create trigger audit_logs_immutable
  before update or delete on public.audit_logs
  for each row execute function public.forbid_mutation();
"""

TENANT_TABLES = [
    "customers", "product_categories", "products", "quotes", "invoices", "payments", "sales",
    "warehouses", "stock_movements", "stores", "cash_registers", "cash_transactions",
    "suppliers", "purchases", "expenses", "deliveries",
]
CHILD_TABLES = {
    "quote_items": ("quotes", "quote_id"),
    "invoice_items": ("invoices", "invoice_id"),
    "sale_items": ("sales", "sale_id"),
    "purchase_items": ("purchases", "purchase_id"),
}

rls = HEADER.format(name="036_rls_policies", desc="Row Level Security. The API uses the service role after its own checks; these policies are the second line of defence for any direct Supabase access (anon/authenticated JWT).") + """
-- ---------- identity ----------
alter table public.users enable row level security;
create policy users_self_select on public.users for select using (id = auth.uid());
create policy users_self_update on public.users for update using (id = auth.uid()) with check (id = auth.uid());

alter table public.personal_workspaces enable row level security;
create policy personal_workspaces_owner_select on public.personal_workspaces
  for select using (user_id = auth.uid());
create policy personal_workspaces_owner_update on public.personal_workspaces
  for update using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.organizations enable row level security;
create policy organizations_member_select on public.organizations
  for select using (public.is_org_member(id));

alter table public.organization_members enable row level security;
create policy organization_members_visible_to_members on public.organization_members
  for select using (user_id = auth.uid() or public.is_org_member(organization_id));

alter table public.roles enable row level security;
create policy roles_readable on public.roles
  for select using (organization_id is null or public.is_org_member(organization_id));

alter table public.permissions enable row level security;
create policy permissions_readable on public.permissions for select using (auth.role() = 'authenticated');

alter table public.role_permissions enable row level security;
create policy role_permissions_readable on public.role_permissions
  for select using (exists (
    select 1 from public.roles r where r.id = role_id and (r.organization_id is null or public.is_org_member(r.organization_id))
  ));

-- Writes to identity/RBAC tables go exclusively through the API (service role).

-- ---------- business tables: read-only through RLS, writes via API ----------
"""
for t in TENANT_TABLES:
    rls += f"""
alter table public.{t} enable row level security;
create policy {t}_tenant_select on public.{t}
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));
"""
for child, (parent, fk) in CHILD_TABLES.items():
    rls += f"""
alter table public.{child} enable row level security;
create policy {child}_tenant_select on public.{child}
  for select using (exists (
    select 1 from public.{parent} p where p.id = {fk}
      and public.can_access_tenant(p.personal_workspace_id, p.organization_id)
  ));
"""
rls += """
alter table public.stock_levels enable row level security;
create policy stock_levels_tenant_select on public.stock_levels
  for select using (exists (
    select 1 from public.warehouses w where w.id = warehouse_id
      and public.can_access_tenant(w.personal_workspace_id, w.organization_id)
  ));

-- ---------- platform tables ----------
alter table public.ai_credits enable row level security;
create policy ai_credits_tenant_select on public.ai_credits
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.ai_action_costs enable row level security;
create policy ai_action_costs_readable on public.ai_action_costs for select using (auth.role() = 'authenticated');

alter table public.ai_usage enable row level security;
create policy ai_usage_tenant_select on public.ai_usage
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.subscriptions enable row level security;
create policy subscriptions_tenant_select on public.subscriptions
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.plans enable row level security;
create policy plans_readable on public.plans for select using (is_active);

alter table public.audit_logs enable row level security;
create policy audit_logs_tenant_select on public.audit_logs
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

-- No client access at all: service role only.
alter table public.device_installations enable row level security;
alter table public.anti_abuse_events enable row level security;
"""
MIGRATIONS["036_rls_policies.sql"] = rls

MIGRATIONS["037_indexes.sql"] = HEADER.format(name="037_indexes", desc="Cross-cutting indexes for dashboards, search and sync.") + """
create index customers_updated_at_idx on public.customers(updated_at);
create index products_updated_at_idx on public.products(updated_at);
create index quotes_updated_at_idx on public.quotes(updated_at);
create index invoices_updated_at_idx on public.invoices(updated_at);
create index payments_updated_at_idx on public.payments(updated_at);
create index sales_sold_at_idx on public.sales(sold_at);

create index products_low_stock_idx on public.products(id) where track_stock;
create index invoices_open_idx on public.invoices(due_date) where status in ('SENT', 'PARTIALLY_PAID', 'OVERDUE');

create index products_search_idx on public.products using gin (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(sku, '') || ' ' || coalesce(barcode, '')));
"""

PERMS = [
    ("customers", ["read", "create", "update", "delete"]),
    ("products", ["read", "create", "update", "delete"]),
    ("quotes", ["read", "create", "update", "delete", "send"]),
    ("invoices", ["read", "create", "update", "cancel", "send"]),
    ("payments", ["read", "create", "refund"]),
    ("sales", ["read", "create"]),
    ("inventory", ["read", "adjust", "transfer"]),
    ("purchases", ["read", "create", "receive"]),
    ("suppliers", ["read", "manage"]),
    ("expenses", ["read", "create", "update"]),
    ("cash", ["read", "operate"]),
    ("deliveries", ["read", "manage"]),
    ("reports", ["read", "financial"]),
    ("team", ["read", "manage"]),
    ("settings", ["manage"]),
    ("ai", ["use"]),
]
ALL_PERMS = [f"{r}.{a}" for r, acts in PERMS for a in acts]
READ_ALL = [p for p in ALL_PERMS if p.endswith(".read")]

ROLE_PERMS = {
    "OWNER": ALL_PERMS,
    "ADMIN": [p for p in ALL_PERMS],
    "MANAGER": [p for p in ALL_PERMS if p not in ("settings.manage", "team.manage", "payments.refund")],
    "ACCOUNTANT": READ_ALL + ["invoices.create", "invoices.update", "invoices.send", "invoices.cancel", "payments.create", "payments.refund", "expenses.create", "expenses.update", "reports.financial", "ai.use"],
    "SALES": ["customers.read", "customers.create", "customers.update", "products.read", "quotes.read", "quotes.create", "quotes.update", "quotes.send", "invoices.read", "invoices.create", "invoices.send", "sales.read", "sales.create", "payments.read", "payments.create", "inventory.read", "deliveries.read", "ai.use"],
    "STOCK_MANAGER": ["products.read", "products.create", "products.update", "inventory.read", "inventory.adjust", "inventory.transfer", "purchases.read", "purchases.create", "purchases.receive", "suppliers.read", "suppliers.manage", "deliveries.read", "ai.use"],
    "CASHIER": ["customers.read", "products.read", "sales.read", "sales.create", "payments.read", "payments.create", "invoices.read", "cash.read", "cash.operate"],
    "DELIVERY": ["customers.read", "deliveries.read", "deliveries.manage"],
    "VIEWER": READ_ALL,
}
ROLE_NAMES = {
    "OWNER": "Propriétaire", "ADMIN": "Administrateur", "MANAGER": "Manager", "ACCOUNTANT": "Comptable",
    "SALES": "Commercial", "STOCK_MANAGER": "Gestionnaire de stock", "CASHIER": "Caissier",
    "DELIVERY": "Livreur", "VIEWER": "Lecteur",
}

seed = HEADER.format(name="038_seed_data", desc="Reference data: permissions, system roles, AI action costs, plans. Idempotent.") + "\n-- permissions\ninsert into public.permissions (code, resource, action) values\n"
seed += ",\n".join(f"  ('{r}.{a}', '{r}', '{a}')" for r, acts in PERMS for a in acts) + "\non conflict (code) do nothing;\n"
seed += "\n-- system roles\ninsert into public.roles (code, name, is_system) values\n"
seed += ",\n".join(f"  ('{c}', '{n}', true)" for c, n in ROLE_NAMES.items()) + "\non conflict do nothing;\n"
seed += "\n-- role -> permissions\n"
for role, perms in ROLE_PERMS.items():
    seed += f"insert into public.role_permissions (role_id, permission_code)\nselect r.id, p.code from public.roles r, public.permissions p\nwhere r.code = '{role}' and r.organization_id is null and p.code in (\n  "
    seed += ", ".join(f"'{p}'" for p in perms)
    seed += "\n)\non conflict do nothing;\n\n"
seed += """-- AI action costs (configurable)
insert into public.ai_action_costs (action, credits, description) values
  ('simple_question', 1, 'Question simple'),
  ('message', 1, 'Rédaction de message'),
  ('quote', 2, 'Création de devis'),
  ('invoice', 2, 'Création de facture'),
  ('customer_analysis', 3, 'Analyse client'),
  ('ocr', 5, 'OCR de document'),
  ('stock_analysis', 5, 'Analyse de stock'),
  ('sales_analysis', 5, 'Analyse des ventes'),
  ('financial_report', 10, 'Rapport financier'),
  ('full_report', 15, 'Rapport complet')
on conflict (action) do nothing;

-- Official plans. Prices are XOF/month; AI quotas are user-visible tokens.
insert into public.plans (code, name, audience, price_monthly, price_yearly, ai_credits_monthly, limits, features) values
  ('FREE', 'Gratuit', 'BOTH', 0, 0, 500, '{"invoices_per_month": 10, "members": 1}', '{"free_bonus_once": true}'),
  ('PERSONAL', 'Personnel', 'PERSONAL', 1500, 18000, 10000, '{"invoices_per_month": null, "members": 1}', '{}'),
  ('BUSINESS_STARTER', 'Business Starter', 'ORGANIZATION', 7500, 90000, 35000, '{"invoices_per_month": null, "members": 5}', '{}'),
  ('BUSINESS', 'Business', 'ORGANIZATION', 15000, 180000, 60000, '{"invoices_per_month": null, "members": 10}', '{}'),
  ('BUSINESS_PRO', 'Business Pro', 'ORGANIZATION', 30000, 360000, 100000, '{"invoices_per_month": null, "members": null}', '{}')
on conflict (code) do update set
  name = excluded.name,
  audience = excluded.audience,
  price_monthly = excluded.price_monthly,
  price_yearly = excluded.price_yearly,
  ai_credits_monthly = excluded.ai_credits_monthly,
  limits = excluded.limits,
  features = excluded.features,
  is_active = true,
  updated_at = now();

update public.plans set is_active = false
 where code not in ('FREE', 'PERSONAL', 'BUSINESS_STARTER', 'BUSINESS', 'BUSINESS_PRO');
"""
MIGRATIONS["038_seed_data.sql"] = seed

MIGRATIONS["039_ai_billing.sql"] = HEADER.format(
    name="039_ai_billing",
    desc="User wallets, strict AI reservations, payments, and provider cost tracking.",
) + """
-- The free bonus is account-scoped, never workspace/device/session-scoped.
alter table public.users
  add column if not exists free_ai_bonus_granted_at timestamptz;

create table public.ai_wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete restrict,
  balance integer not null default 0 check (balance >= 0),
  lifetime_credited integer not null default 0 check (lifetime_credited >= 0),
  lifetime_consumed integer not null default 0 check (lifetime_consumed >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_ai_wallets_updated_at
  before update on public.ai_wallets
  for each row execute function public.set_updated_at();

create table public.ai_wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.ai_wallets(id) on delete restrict,
  user_id uuid not null references public.users(id) on delete restrict,
  kind text not null check (kind in ('FREE_BONUS', 'PLAN_GRANT', 'TOP_UP', 'RESERVATION', 'CONSUMPTION', 'REFUND', 'EXPIRATION', 'ADJUSTMENT')),
  amount integer not null check (amount <> 0 or kind = 'CONSUMPTION'),
  idempotency_key text unique,
  provider text,
  provider_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index ai_wallet_transactions_user_created_idx
  on public.ai_wallet_transactions(user_id, created_at desc);

create table public.ai_reservations (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.ai_wallets(id) on delete restrict,
  user_id uuid not null references public.users(id) on delete restrict,
  amount integer not null check (amount > 0),
  status text not null default 'RESERVED' check (status in ('RESERVED', 'COMMITTED', 'REFUNDED', 'EXPIRED')),
  provider text,
  action text not null,
  idempotency_key text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create index ai_reservations_user_status_idx
  on public.ai_reservations(user_id, status);

create table public.billing_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  currency char(3) not null default 'XOF',
  provider text not null default 'GENIUSPAY',
  provider_reference text not null,
  status text not null default 'PENDING' check (status in ('PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
  kind text not null check (kind in ('SUBSCRIPTION', 'AI_TOP_UP')),
  metadata jsonb not null default '{}'::jsonb,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_reference)
);

create trigger set_payments_updated_at
  before update on public.billing_payments
  for each row execute function public.set_updated_at();

create table public.ai_provider_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete restrict,
  reservation_id uuid references public.ai_reservations(id) on delete restrict,
  provider text not null check (provider in ('CLAUDE', 'OPENAI')),
  model text not null,
  input_tokens integer not null default 0 check (input_tokens >= 0),
  output_tokens integer not null default 0 check (output_tokens >= 0),
  cost_xof numeric(12,4) not null default 0 check (cost_xof >= 0),
  succeeded boolean not null,
  created_at timestamptz not null default now()
);

create index ai_provider_usage_user_created_idx
  on public.ai_provider_usage(user_id, created_at desc);

alter table public.ai_wallets enable row level security;
create policy ai_wallets_self_select on public.ai_wallets
  for select using (user_id = auth.uid());

alter table public.ai_wallet_transactions enable row level security;
create policy ai_wallet_transactions_self_select on public.ai_wallet_transactions
  for select using (user_id = auth.uid());

alter table public.ai_reservations enable row level security;
create policy ai_reservations_self_select on public.ai_reservations
  for select using (user_id = auth.uid());

alter table public.billing_payments enable row level security;
create policy billing_payments_self_select on public.billing_payments
  for select using (user_id = auth.uid());

alter table public.ai_provider_usage enable row level security;
create policy ai_provider_usage_self_select on public.ai_provider_usage
  for select using (user_id = auth.uid());

-- Wallet writes are atomic and account-scoped. Callers must use the backend.
create or replace function public.grant_free_ai_bonus(p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
begin
  update public.users
     set free_ai_bonus_granted_at = coalesce(free_ai_bonus_granted_at, now())
   where id = p_user_id and free_ai_bonus_granted_at is null;

  if not found then
    select id into v_wallet_id from public.ai_wallets where user_id = p_user_id;
    return v_wallet_id;
  end if;

  insert into public.ai_wallets (user_id, balance, lifetime_credited)
  values (p_user_id, 500, 500)
  on conflict (user_id) do update
    set balance = public.ai_wallets.balance + 500,
        lifetime_credited = public.ai_wallets.lifetime_credited + 500
  returning id into v_wallet_id;

  insert into public.ai_wallet_transactions
    (wallet_id, user_id, kind, amount, idempotency_key)
  values
    (v_wallet_id, p_user_id, 'FREE_BONUS', 500, 'free-bonus:' || p_user_id)
  on conflict (idempotency_key) do nothing;

  return v_wallet_id;
end;
$$;

create or replace function public.reserve_ai_tokens(
  p_user_id uuid,
  p_amount integer,
  p_action text,
  p_provider text,
  p_idempotency_key text,
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_reservation_id uuid;
begin
  if p_amount <= 0 then raise exception 'AI reservation amount must be positive'; end if;

  select id into v_reservation_id
    from public.ai_reservations
   where idempotency_key = p_idempotency_key;
  if v_reservation_id is not null then return v_reservation_id; end if;

  select id into v_wallet_id
    from public.ai_wallets
   where user_id = p_user_id
   for update;
  if v_wallet_id is null then raise exception 'AI wallet not found'; end if;

  update public.ai_wallets
     set balance = balance - p_amount
   where id = v_wallet_id and balance >= p_amount;
  if not found then raise exception 'AI quota insufficient'; end if;

  insert into public.ai_reservations
    (wallet_id, user_id, amount, provider, action, idempotency_key, expires_at)
  values
    (v_wallet_id, p_user_id, p_amount, p_provider, p_action, p_idempotency_key, p_expires_at)
  returning id into v_reservation_id;

  insert into public.ai_wallet_transactions
    (wallet_id, user_id, kind, amount, idempotency_key, provider)
  values
    (v_wallet_id, p_user_id, 'RESERVATION', -p_amount, 'reservation:' || p_idempotency_key, p_provider);

  return v_reservation_id;
end;
$$;

create or replace function public.complete_ai_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_user_id uuid;
  v_amount integer;
begin
  update public.ai_reservations
     set status = 'COMMITTED', completed_at = now()
   where id = p_reservation_id and status = 'RESERVED'
   returning wallet_id, user_id, amount into v_wallet_id, v_user_id, v_amount;
  if found then
    update public.ai_wallets
       set lifetime_consumed = lifetime_consumed + v_amount
     where id = v_wallet_id;
    insert into public.ai_wallet_transactions
      (wallet_id, user_id, kind, amount, idempotency_key)
    values
      (v_wallet_id, v_user_id, 'CONSUMPTION', 0, 'consumption:' || p_reservation_id)
    on conflict (idempotency_key) do nothing;
  end if;
end;
$$;

create or replace function public.refund_ai_reservation(p_reservation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet_id uuid;
  v_user_id uuid;
  v_amount integer;
begin
  update public.ai_reservations
     set status = 'REFUNDED', completed_at = now()
   where id = p_reservation_id and status = 'RESERVED'
   returning wallet_id, user_id, amount into v_wallet_id, v_user_id, v_amount;
  if found then
    update public.ai_wallets
       set balance = balance + v_amount
     where id = v_wallet_id;
    insert into public.ai_wallet_transactions
      (wallet_id, user_id, kind, amount, idempotency_key)
    values
      (v_wallet_id, v_user_id, 'REFUND', v_amount, 'refund:' || p_reservation_id)
    on conflict (idempotency_key) do nothing;
  end if;
end;
$$;
"""


def main() -> None:
    force = "--force" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    assert len(MIGRATIONS) == 39, len(MIGRATIONS)
    for name, sql in MIGRATIONS.items():
        path = OUT / name
        if path.exists() and not force and "TODO: implement" not in path.read_text():
            print(f"skip {name} (exists)")
            continue
        path.write_text(sql.lstrip("\n") if not sql.startswith("--") else sql)
        print(f"wrote {name}")


if __name__ == "__main__":
    main()
