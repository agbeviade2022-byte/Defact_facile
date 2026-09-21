import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plus')),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          Text('Gestion du compte', style: AppTypography.h2),
          AppSpacing.gapSm,
          Text(
            'Retrouvez ici les réglages et services disponibles pour votre espace.',
            style: AppTypography.bodySecondary,
          ),
          AppSpacing.gapMd,
          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Voir les forfaits'),
              subtitle: const Text('Comparer les offres disponibles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.plans),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Assistant IA'),
              subtitle: const Text('Obtenir une réponse pour votre activité'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.assistant),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Wallet IA'),
              subtitle: const Text('Consulter et recharger vos crédits'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.aiWallet),
            ),
          ),
        ],
      ),
    );
  }
}
