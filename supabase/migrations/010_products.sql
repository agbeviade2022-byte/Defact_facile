-- DEFACT FACILE migration: products
-- Products and services.

create table public.products (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint products_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  category_id uuid references public.product_categories(id) on delete set null,
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
  is_archived boolean not null default false,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_personal_workspace_idx on public.products(personal_workspace_id) where personal_workspace_id is not null;
create index products_organization_idx on public.products(organization_id) where organization_id is not null;

create trigger set_products_updated_at
  before update on public.products
  for each row execute function public.set_updated_at();

create unique index products_sku_per_org on public.products(organization_id, sku) where organization_id is not null and sku is not null;
create unique index products_sku_per_ws on public.products(personal_workspace_id, sku) where personal_workspace_id is not null and sku is not null;
