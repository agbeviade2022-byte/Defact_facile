-- DEFACT FACILE migration: 038_seed_data
-- Reference data: permissions, system roles, AI action costs, plans. Idempotent.


-- permissions
insert into public.permissions (code, resource, action) values
  ('customers.read', 'customers', 'read'),
  ('customers.create', 'customers', 'create'),
  ('customers.update', 'customers', 'update'),
  ('customers.delete', 'customers', 'delete'),
  ('products.read', 'products', 'read'),
  ('products.create', 'products', 'create'),
  ('products.update', 'products', 'update'),
  ('products.delete', 'products', 'delete'),
  ('quotes.read', 'quotes', 'read'),
  ('quotes.create', 'quotes', 'create'),
  ('quotes.update', 'quotes', 'update'),
  ('quotes.delete', 'quotes', 'delete'),
  ('quotes.send', 'quotes', 'send'),
  ('invoices.read', 'invoices', 'read'),
  ('invoices.create', 'invoices', 'create'),
  ('invoices.update', 'invoices', 'update'),
  ('invoices.cancel', 'invoices', 'cancel'),
  ('invoices.send', 'invoices', 'send'),
  ('payments.read', 'payments', 'read'),
  ('payments.create', 'payments', 'create'),
  ('payments.refund', 'payments', 'refund'),
  ('sales.read', 'sales', 'read'),
  ('sales.create', 'sales', 'create'),
  ('inventory.read', 'inventory', 'read'),
  ('inventory.adjust', 'inventory', 'adjust'),
  ('inventory.transfer', 'inventory', 'transfer'),
  ('purchases.read', 'purchases', 'read'),
  ('purchases.create', 'purchases', 'create'),
  ('purchases.receive', 'purchases', 'receive'),
  ('suppliers.read', 'suppliers', 'read'),
  ('suppliers.manage', 'suppliers', 'manage'),
  ('expenses.read', 'expenses', 'read'),
  ('expenses.create', 'expenses', 'create'),
  ('expenses.update', 'expenses', 'update'),
  ('cash.read', 'cash', 'read'),
  ('cash.operate', 'cash', 'operate'),
  ('deliveries.read', 'deliveries', 'read'),
  ('deliveries.manage', 'deliveries', 'manage'),
  ('reports.read', 'reports', 'read'),
  ('reports.financial', 'reports', 'financial'),
  ('team.read', 'team', 'read'),
  ('team.manage', 'team', 'manage'),
  ('settings.manage', 'settings', 'manage'),
  ('ai.use', 'ai', 'use')
on conflict (code) do nothing;

-- system roles
insert into public.roles (code, name, is_system) values
  ('OWNER', 'Propriétaire', true),
  ('ADMIN', 'Administrateur', true),
  ('MANAGER', 'Manager', true),
  ('ACCOUNTANT', 'Comptable', true),
  ('SALES', 'Commercial', true),
  ('STOCK_MANAGER', 'Gestionnaire de stock', true),
  ('CASHIER', 'Caissier', true),
  ('DELIVERY', 'Livreur', true),
  ('VIEWER', 'Lecteur', true)
on conflict do nothing;

-- role -> permissions
insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'OWNER' and r.organization_id is null and p.code in (
  'customers.read', 'customers.create', 'customers.update', 'customers.delete', 'products.read', 'products.create', 'products.update', 'products.delete', 'quotes.read', 'quotes.create', 'quotes.update', 'quotes.delete', 'quotes.send', 'invoices.read', 'invoices.create', 'invoices.update', 'invoices.cancel', 'invoices.send', 'payments.read', 'payments.create', 'payments.refund', 'sales.read', 'sales.create', 'inventory.read', 'inventory.adjust', 'inventory.transfer', 'purchases.read', 'purchases.create', 'purchases.receive', 'suppliers.read', 'suppliers.manage', 'expenses.read', 'expenses.create', 'expenses.update', 'cash.read', 'cash.operate', 'deliveries.read', 'deliveries.manage', 'reports.read', 'reports.financial', 'team.read', 'team.manage', 'settings.manage', 'ai.use'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'ADMIN' and r.organization_id is null and p.code in (
  'customers.read', 'customers.create', 'customers.update', 'customers.delete', 'products.read', 'products.create', 'products.update', 'products.delete', 'quotes.read', 'quotes.create', 'quotes.update', 'quotes.delete', 'quotes.send', 'invoices.read', 'invoices.create', 'invoices.update', 'invoices.cancel', 'invoices.send', 'payments.read', 'payments.create', 'payments.refund', 'sales.read', 'sales.create', 'inventory.read', 'inventory.adjust', 'inventory.transfer', 'purchases.read', 'purchases.create', 'purchases.receive', 'suppliers.read', 'suppliers.manage', 'expenses.read', 'expenses.create', 'expenses.update', 'cash.read', 'cash.operate', 'deliveries.read', 'deliveries.manage', 'reports.read', 'reports.financial', 'team.read', 'team.manage', 'settings.manage', 'ai.use'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'MANAGER' and r.organization_id is null and p.code in (
  'customers.read', 'customers.create', 'customers.update', 'customers.delete', 'products.read', 'products.create', 'products.update', 'products.delete', 'quotes.read', 'quotes.create', 'quotes.update', 'quotes.delete', 'quotes.send', 'invoices.read', 'invoices.create', 'invoices.update', 'invoices.cancel', 'invoices.send', 'payments.read', 'payments.create', 'sales.read', 'sales.create', 'inventory.read', 'inventory.adjust', 'inventory.transfer', 'purchases.read', 'purchases.create', 'purchases.receive', 'suppliers.read', 'suppliers.manage', 'expenses.read', 'expenses.create', 'expenses.update', 'cash.read', 'cash.operate', 'deliveries.read', 'deliveries.manage', 'reports.read', 'reports.financial', 'team.read', 'ai.use'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'ACCOUNTANT' and r.organization_id is null and p.code in (
  'customers.read', 'products.read', 'quotes.read', 'invoices.read', 'payments.read', 'sales.read', 'inventory.read', 'purchases.read', 'suppliers.read', 'expenses.read', 'cash.read', 'deliveries.read', 'reports.read', 'team.read', 'invoices.create', 'invoices.update', 'invoices.send', 'invoices.cancel', 'payments.create', 'payments.refund', 'expenses.create', 'expenses.update', 'reports.financial', 'ai.use'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'SALES' and r.organization_id is null and p.code in (
  'customers.read', 'customers.create', 'customers.update', 'products.read', 'quotes.read', 'quotes.create', 'quotes.update', 'quotes.send', 'invoices.read', 'invoices.create', 'invoices.send', 'sales.read', 'sales.create', 'payments.read', 'payments.create', 'inventory.read', 'deliveries.read', 'ai.use'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'STOCK_MANAGER' and r.organization_id is null and p.code in (
  'products.read', 'products.create', 'products.update', 'inventory.read', 'inventory.adjust', 'inventory.transfer', 'purchases.read', 'purchases.create', 'purchases.receive', 'suppliers.read', 'suppliers.manage', 'deliveries.read', 'ai.use'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'CASHIER' and r.organization_id is null and p.code in (
  'customers.read', 'products.read', 'sales.read', 'sales.create', 'payments.read', 'payments.create', 'invoices.read', 'cash.read', 'cash.operate'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'DELIVERY' and r.organization_id is null and p.code in (
  'customers.read', 'deliveries.read', 'deliveries.manage'
)
on conflict do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code from public.roles r, public.permissions p
where r.code = 'VIEWER' and r.organization_id is null and p.code in (
  'customers.read', 'products.read', 'quotes.read', 'invoices.read', 'payments.read', 'sales.read', 'inventory.read', 'purchases.read', 'suppliers.read', 'expenses.read', 'cash.read', 'deliveries.read', 'reports.read', 'team.read'
)
on conflict do nothing;

-- AI action costs (configurable)
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

-- Plans
insert into public.plans (code, name, audience, price_monthly, price_yearly, ai_credits_monthly, limits) values
  ('FREE', 'Gratuit', 'BOTH', 0, 0, 10, '{"invoices_per_month": 10, "members": 1}'),
  ('SOLO', 'Solo', 'PERSONAL', 5000, 50000, 100, '{"invoices_per_month": null, "members": 1}'),
  ('BUSINESS', 'Entreprise', 'ORGANIZATION', 15000, 150000, 500, '{"invoices_per_month": null, "members": 10}'),
  ('BUSINESS_PLUS', 'Entreprise+', 'ORGANIZATION', 35000, 350000, 2000, '{"invoices_per_month": null, "members": null}')
on conflict (code) do nothing;
