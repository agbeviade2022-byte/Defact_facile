-- DEFACT FACILE migration: 019_stock_levels
-- Materialised current quantity per product per warehouse. Derived from stock_movements.


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
