-- DEFACT FACILE migration: product_categories
-- Hierarchical product categories.

create table public.product_categories (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint product_categories_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  name text not null,
  parent_id uuid references public.product_categories(id) on delete set null,
  position integer not null default 0,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index product_categories_personal_workspace_idx on public.product_categories(personal_workspace_id) where personal_workspace_id is not null;
create index product_categories_organization_idx on public.product_categories(organization_id) where organization_id is not null;

create trigger set_product_categories_updated_at
  before update on public.product_categories
  for each row execute function public.set_updated_at();
