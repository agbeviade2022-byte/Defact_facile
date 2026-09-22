import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/reference_ui.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          Card(
            child: Padding(
              padding: AppSpacing.card,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primarySoft,
                    foregroundColor: AppColors.primary,
                    child: const Icon(Icons.storefront_outlined, size: 28),
                  ),
                  AppSpacing.gapMd,
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DEFACT FACILE',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text('Votre espace de gestion'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          AppSpacing.gapXl,
          Text('Paramètres', style: AppTypography.h2),
          AppSpacing.gapXs,
          Text(
            'Personnalisez vos documents et gérez les services de votre espace.',
            style: AppTypography.bodySecondary,
          ),
          AppSpacing.gapMd,
          ReferenceListCard(
            icon: Icons.groups_outlined,
            title: 'Équipe',
            subtitle: 'Voir les membres de l’entreprise',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.team),
          ),
          AppSpacing.gapXl,
          Text('Services', style: AppTypography.h3),
          AppSpacing.gapSm,
          ReferenceListCard(
            icon: Icons.workspace_premium_outlined,
            title: 'Voir les forfaits',
            subtitle: 'Comparer les offres disponibles',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.plans),
          ),
          AppSpacing.gapSm,
          ReferenceListCard(
            icon: Icons.chat_bubble_outline,
            title: 'Assistant IA',
            subtitle: 'Obtenir une réponse pour votre activité',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.assistant),
          ),
          AppSpacing.gapSm,
          ReferenceListCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Wallet IA',
            subtitle: 'Consulter et recharger vos crédits',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.aiWallet),
          ),
        ],
      ),
    );
  }
}
