-- DEFACT FACILE migration: 012_quote_items
-- Quote line items.


create table public.quote_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
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
  created_at timestamptz not null default now()
);

create index quote_items_quote_idx on public.quote_items(quote_id);
