import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Lets the user pick between the personal workspace and one of the
/// organizations they belong to. Real data comes with Mission 03.
class WorkspaceSelectorScreen extends StatelessWidget {
  const WorkspaceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choisir un espace')),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          Text('Espace personnel', style: AppTypography.h3),
          AppSpacing.gapSm,
          _WorkspaceTile(
            icon: Icons.person_outline,
            title: 'Mon espace',
            subtitle: 'Devis, factures et clients personnels',
            onTap: () => context.go(AppRoutes.personalHome),
          ),
          AppSpacing.gapXl,
          Text('Entreprises', style: AppTypography.h3),
          AppSpacing.gapSm,
          _WorkspaceTile(
            icon: Icons.storefront_outlined,
            title: 'Entreprise de démonstration',
            subtitle: 'Ventes, stock, caisse et équipe',
            onTap: () => context.go(AppRoutes.businessHome),
          ),
          AppSpacing.gapMd,
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.onboarding),
            icon: const Icon(Icons.add),
            label: const Text('Créer une entreprise'),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: AppTypography.bodyLarge),
        subtitle: Text(subtitle, style: AppTypography.bodySecondary),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
