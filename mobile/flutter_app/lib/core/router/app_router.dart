import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/workspaces/presentation/workspace_selector_screen.dart';
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
            _placeholder(
              AppRoutes.personalQuotes,
              'Devis',
              'Mission 05',
              Icons.description_outlined,
            ),
          ),
          _branch(
            _placeholder(
              AppRoutes.personalInvoices,
              'Factures',
              'Mission 05',
              Icons.receipt_long_outlined,
            ),
          ),
          _branch(
            _placeholder(
              AppRoutes.personalCustomers,
              'Clients',
              'Mission 04',
              Icons.people_outline,
            ),
          ),
          _branch(
            _placeholder(
              AppRoutes.personalMore,
              'Plus',
              'Mission 03',
              Icons.more_horiz,
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
            _placeholder(
              AppRoutes.businessInvoices,
              'Factures',
              'Mission 05',
              Icons.receipt_long_outlined,
            ),
          ),
          _branch(
            _placeholder(
              AppRoutes.businessInventory,
              'Stock',
              'Mission 07',
              Icons.inventory_2_outlined,
            ),
          ),
          _branch(
            _placeholder(
              AppRoutes.businessCustomers,
              'Clients',
              'Mission 04',
              Icons.people_outline,
            ),
          ),
          _branch(
            _placeholder(
              AppRoutes.businessMore,
              'Plus',
              'Mission 03',
              Icons.more_horiz,
            ),
          ),
        ],
      ),
    ],
  );
}
