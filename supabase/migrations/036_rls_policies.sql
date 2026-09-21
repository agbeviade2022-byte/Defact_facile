-- DEFACT FACILE migration: 036_rls_policies
-- Row Level Security. The API uses the service role after its own checks; these policies are the second line of defence for any direct Supabase access (anon/authenticated JWT).


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

alter table public.customers enable row level security;
create policy customers_tenant_select on public.customers
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.product_categories enable row level security;
create policy product_categories_tenant_select on public.product_categories
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.products enable row level security;
create policy products_tenant_select on public.products
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.quotes enable row level security;
create policy quotes_tenant_select on public.quotes
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.invoices enable row level security;
create policy invoices_tenant_select on public.invoices
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.payments enable row level security;
create policy payments_tenant_select on public.payments
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.sales enable row level security;
create policy sales_tenant_select on public.sales
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.warehouses enable row level security;
create policy warehouses_tenant_select on public.warehouses
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.stock_movements enable row level security;
create policy stock_movements_tenant_select on public.stock_movements
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.stores enable row level security;
create policy stores_tenant_select on public.stores
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.cash_registers enable row level security;
create policy cash_registers_tenant_select on public.cash_registers
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.cash_transactions enable row level security;
create policy cash_transactions_tenant_select on public.cash_transactions
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.suppliers enable row level security;
create policy suppliers_tenant_select on public.suppliers
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.purchases enable row level security;
create policy purchases_tenant_select on public.purchases
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.expenses enable row level security;
create policy expenses_tenant_select on public.expenses
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.deliveries enable row level security;
create policy deliveries_tenant_select on public.deliveries
  for select using (public.can_access_tenant(personal_workspace_id, organization_id));

alter table public.quote_items enable row level security;
create policy quote_items_tenant_select on public.quote_items
  for select using (exists (
    select 1 from public.quotes p where p.id = quote_id
      and public.can_access_tenant(p.personal_workspace_id, p.organization_id)
  ));

alter table public.invoice_items enable row level security;
create policy invoice_items_tenant_select on public.invoice_items
  for select using (exists (
    select 1 from public.invoices p where p.id = invoice_id
      and public.can_access_tenant(p.personal_workspace_id, p.organization_id)
  ));

alter table public.sale_items enable row level security;
create policy sale_items_tenant_select on public.sale_items
  for select using (exists (
    select 1 from public.sales p where p.id = sale_id
      and public.can_access_tenant(p.personal_workspace_id, p.organization_id)
  ));

alter table public.purchase_items enable row level security;
create policy purchase_items_tenant_select on public.purchase_items
  for select using (exists (
    select 1 from public.purchases p where p.id = purchase_id
      and public.can_access_tenant(p.personal_workspace_id, p.organization_id)
  ));

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
