import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/workspaces/presentation/workspace_selector_screen.dart';
import '../../features/plans/presentation/plans_screen.dart';
import '../../features/more/presentation/more_screen.dart';
import '../../features/ai_wallet/presentation/ai_wallet_screen.dart';
import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/team/presentation/team_screen.dart';
import '../../features/customers/presentation/customers_screen.dart';
import '../../features/quotes/presentation/quotes_screen.dart';
import '../../features/invoices/presentation/invoices_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../shared/widgets/app_states.dart';
import '../../shared/widgets/placeholder_screen.dart';
import 'app_routes.dart';
import 'workspace_shell.dart';

final routerProvider = Provider<GoRouter>((ref) => buildRouter());

const _personalDestinations = [
  ShellDestination(
    route: AppRoutes.personalHome,
    label: 'Accueil',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  ShellDestination(
    route: AppRoutes.personalQuotes,
    label: 'Devis',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
  ),
  ShellDestination(
    route: AppRoutes.personalInvoices,
    label: 'Factures',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
  ShellDestination(
    route: AppRoutes.personalCustomers,
    label: 'Clients',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  ShellDestination(
    route: AppRoutes.personalMore,
    label: 'Plus',
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
  ),
];

const _businessDestinations = [
  ShellDestination(
    route: AppRoutes.businessHome,
    label: 'Accueil',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  ShellDestination(
    route: AppRoutes.businessSales,
    label: 'Ventes',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
  ),
  ShellDestination(
    route: AppRoutes.businessInvoices,
    label: 'Factures',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
  ShellDestination(
    route: AppRoutes.businessInventory,
    label: 'Stock',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  ShellDestination(
    route: AppRoutes.businessCustomers,
    label: 'Clients',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
  ),
  ShellDestination(
    route: AppRoutes.businessMore,
    label: 'Plus',
    icon: Icons.more_horiz,
    selectedIcon: Icons.more_horiz,
  ),
];

GoRoute _placeholder(String path, String title, String mission, IconData icon) {
  return GoRoute(
    path: path,
    builder: (_, _) =>
        PlaceholderScreen(title: title, mission: mission, icon: icon),
  );
}

StatefulShellBranch _branch(GoRoute route) =>
    StatefulShellBranch(routes: [route]);

GoRouter buildRouter({String initialLocation = AppRoutes.splash}) {
  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: AppErrorState(
        title: 'Page introuvable',
        message: "L'adresse ${state.uri} ne correspond à aucun écran.",
        onRetry: () => context.go(AppRoutes.splash),
      ),
    ),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      _placeholder(
        AppRoutes.onboarding,
        'Créer une entreprise',
        'Mission 03',
        Icons.storefront_outlined,
      ),
      GoRoute(
        path: AppRoutes.workspaces,
        builder: (_, _) => const WorkspaceSelectorScreen(),
      ),
      GoRoute(path: AppRoutes.plans, builder: (_, _) => const PlansScreen()),
      GoRoute(
        path: AppRoutes.aiWallet,
        builder: (_, _) => const AiWalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.assistant,
        builder: (_, _) => const AssistantScreen(),
      ),
      GoRoute(
        path: AppRoutes.team,
        builder: (_, _) => const TeamScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => WorkspaceShell(
          destinations: _personalDestinations,
          navigationShell: shell,
        ),
        branches: [
          _branch(
            _placeholder(
              AppRoutes.personalHome,
              'Accueil',
              'Mission 03',
              Icons.home_outlined,
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.personalQuotes,
              builder: (_, _) => const QuotesScreen(),
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.personalInvoices,
              builder: (_, _) => const InvoicesScreen(),
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.personalCustomers,
              builder: (_, _) => const CustomersScreen(),
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.personalMore,
              builder: (_, _) => const MoreScreen(),
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => WorkspaceShell(
          destinations: _businessDestinations,
          navigationShell: shell,
        ),
        branches: [
          _branch(
            _placeholder(
              AppRoutes.businessHome,
              'Accueil',
              'Mission 03',
              Icons.home_outlined,
            ),
          ),
          _branch(
            _placeholder(
              AppRoutes.businessSales,
              'Ventes',
              'Mission 06',
              Icons.point_of_sale_outlined,
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.businessInvoices,
              builder: (_, _) => const InvoicesScreen(),
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.businessInventory,
              builder: (_, _) => const InventoryScreen(),
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.businessCustomers,
              builder: (_, _) => const CustomersScreen(),
            ),
          ),
          _branch(
            GoRoute(
              path: AppRoutes.businessMore,
              builder: (_, _) => const MoreScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
