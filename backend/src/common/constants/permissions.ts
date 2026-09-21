export const PERMISSIONS = [
  'customers.read',
  'customers.create',
  'customers.update',
  'customers.delete',

  'products.read',
  'products.create',
  'products.update',
  'products.delete',

  'quotes.read',
  'quotes.create',
  'quotes.update',
  'quotes.delete',
  'quotes.send',

  'invoices.read',
  'invoices.create',
  'invoices.update',
  'invoices.cancel',
  'invoices.send',

  'payments.read',
  'payments.create',
  'payments.refund',

  'sales.read',
  'sales.create',

  'inventory.read',
  'inventory.adjust',
  'inventory.transfer',

  'purchases.read',
  'purchases.create',
  'purchases.receive',

  'suppliers.read',
  'suppliers.manage',

  'expenses.read',
  'expenses.create',
  'expenses.update',

  'cash.read',
  'cash.operate',

  'deliveries.read',
  'deliveries.manage',

  'reports.read',
  'reports.financial',

  'team.read',
  'team.manage',

  'settings.manage',

  'ai.use',
] as const;

export type Permission = (typeof PERMISSIONS)[number];
