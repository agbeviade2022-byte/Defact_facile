export const SYSTEM_ROLES = [
  'OWNER',
  'ADMIN',
  'MANAGER',
  'ACCOUNTANT',
  'SALES',
  'STOCK_MANAGER',
  'CASHIER',
  'DELIVERY',
  'VIEWER',
] as const;

export type SystemRole = (typeof SYSTEM_ROLES)[number];
