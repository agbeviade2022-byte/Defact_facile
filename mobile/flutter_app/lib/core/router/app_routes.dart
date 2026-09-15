/// Central route table. Feature screens register here so navigation stays
/// discoverable and type-safe-ish (no string literals scattered in widgets).
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String workspaces = '/workspaces';

  // Personal workspace: Accueil / Devis / Factures / Clients / Plus
  static const String personalHome = '/p/home';
  static const String personalQuotes = '/p/quotes';
  static const String personalInvoices = '/p/invoices';
  static const String personalCustomers = '/p/customers';
  static const String personalMore = '/p/more';

  // Business workspace: Accueil / Ventes / Factures / Stock / Clients / Plus
  static const String businessHome = '/b/home';
  static const String businessSales = '/b/sales';
  static const String businessInvoices = '/b/invoices';
  static const String businessInventory = '/b/inventory';
  static const String businessCustomers = '/b/customers';
  static const String businessMore = '/b/more';
}
