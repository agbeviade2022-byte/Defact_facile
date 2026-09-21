-- DEFACT FACILE migration: stock_movements
-- Append-only stock event log. Levels are recomputed from these events (offline-safe).

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  personal_workspace_id uuid references public.personal_workspaces(id) on delete restrict,
  organization_id uuid references public.organizations(id) on delete restrict,
  constraint stock_movements_single_tenant check (
    (personal_workspace_id is not null and organization_id is null) or
    (personal_workspace_id is null and organization_id is not null)
  ),
  product_id uuid not null references public.products(id) on delete restrict,
  warehouse_id uuid not null references public.warehouses(id) on delete restrict,
  type text not null check (type in ('PURCHASE', 'SALE', 'ADJUSTMENT', 'TRANSFER_IN', 'TRANSFER_OUT', 'RETURN')),
  quantity numeric(14,3) not null check (quantity <> 0),
  unit_cost numeric(14,2),
  reference_type text,
  reference_id uuid,
  transfer_group_id uuid,
  reason text,
  occurred_at timestamptz not null default now(),
  client_event_id uuid,
  created_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index stock_movements_personal_workspace_idx on public.stock_movements(personal_workspace_id) where personal_workspace_id is not null;
create index stock_movements_organization_idx on public.stock_movements(organization_id) where organization_id is not null;

create trigger set_stock_movements_updated_at
  before update on public.stock_movements
  for each row execute function public.set_updated_at();

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
