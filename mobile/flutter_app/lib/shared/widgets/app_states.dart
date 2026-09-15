import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

/// Reusable screen states required by ui-ux/06-states/states.md:
/// loading, empty, error, offline, permission denied.

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            AppSpacing.gapMd,
            Text(message!, style: AppTypography.bodySecondary),
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: icon,
      iconColor: AppColors.primary,
      iconBackground: AppColors.primarySoft,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Une erreur est survenue',
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.error_outline,
      iconColor: AppColors.error,
      iconBackground: AppColors.errorSoft,
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : 'Réessayer',
      onAction: onRetry,
    );
  }
}

class AppOfflineState extends StatelessWidget {
  const AppOfflineState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.wifi_off_outlined,
      iconColor: AppColors.warning,
      iconBackground: AppColors.warningSoft,
      title: 'Vous êtes hors ligne',
      message:
          'Vos données mises en cache restent disponibles. '
          'Les modifications seront synchronisées au retour de la connexion.',
      actionLabel: onRetry == null ? null : 'Réessayer',
      onAction: onRetry,
    );
  }
}

class AppPermissionDeniedState extends StatelessWidget {
  const AppPermissionDeniedState({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return _StateScaffold(
      icon: Icons.lock_outline,
      iconColor: AppColors.textSecondary,
      iconBackground: AppColors.divider,
      title: 'Accès non autorisé',
      message:
          "Vous n'avez pas la permission d'accéder à cette section. "
          "Contactez l'administrateur de votre entreprise.",
      actionLabel: onBack == null ? null : 'Retour',
      onAction: onBack,
    );
  }
}

class _StateScaffold extends StatelessWidget {
  const _StateScaffold({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: iconColor),
              ),
              AppSpacing.gapLg,
              Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
              AppSpacing.gapXs,
              Text(
                message,
                style: AppTypography.bodySecondary,
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                AppSpacing.gapXl,
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
