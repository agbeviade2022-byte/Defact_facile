-- DEFACT FACILE migration: 037_indexes
-- Cross-cutting indexes for dashboards, search and sync.


create index customers_updated_at_idx on public.customers(updated_at);
create index products_updated_at_idx on public.products(updated_at);
create index quotes_updated_at_idx on public.quotes(updated_at);
create index invoices_updated_at_idx on public.invoices(updated_at);
create index payments_updated_at_idx on public.payments(updated_at);
create index sales_sold_at_idx on public.sales(sold_at);

create index products_low_stock_idx on public.products(id) where track_stock;
create index invoices_open_idx on public.invoices(due_date) where status in ('SENT', 'PARTIALLY_PAID', 'OVERDUE');

create index products_search_idx on public.products using gin (to_tsvector('simple', coalesce(name, '') || ' ' || coalesce(sku, '') || ' ' || coalesce(barcode, '')));
