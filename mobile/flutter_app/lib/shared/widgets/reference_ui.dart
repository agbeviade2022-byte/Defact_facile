import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class ReferenceSearchField extends StatelessWidget {
  const ReferenceSearchField({
    super.key,
    required this.hintText,
    this.onChanged,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, color: AppColors.textPrimary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

class ReferenceEmptyState extends StatelessWidget {
  const ReferenceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(icon, size: 76, color: AppColors.disabled),
        AppSpacing.gapMd,
        Text(title, textAlign: TextAlign.center, style: AppTypography.h3),
        AppSpacing.gapXs,
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodySecondary,
        ),
        AppSpacing.gapXl,
        Center(
          child: FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class ReferenceListCard extends StatelessWidget {
  const ReferenceListCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(31),
          foregroundColor: iconColor,
          child: Icon(icon),
        ),
        title: Text(title, style: AppTypography.bodyLarge),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing,
      ),
    );
  }
}

class ReferenceSheetAction extends StatelessWidget {
  const ReferenceSheetAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(isLoading ? 'Enregistrement…' : label),
    );
  }
}
