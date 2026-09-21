import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/workspace_repository.dart';

class WorkspaceSelectorScreen extends ConsumerWidget {
  const WorkspaceSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspacesProvider);
    final auth = ref.read(authServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un espace'),
        actions: [
          IconButton(
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: workspaces.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _WorkspaceError(
          message: error is ApiException
              ? error.message
              : 'Erreur de chargement.',
          onRetry: () => ref.invalidate(workspacesProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(workspacesProvider.future),
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              Text('Vos espaces', style: AppTypography.h3),
              AppSpacing.gapSm,
              ...items.map(
                (workspace) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _WorkspaceTile(
                    workspace: workspace,
                    onTap: () => _select(context, ref, workspace),
                  ),
                ),
              ),
              AppSpacing.gapMd,
              OutlinedButton.icon(
                onPressed: () => _createOrganization(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Créer une entreprise'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    WorkspaceSummary workspace,
  ) async {
    try {
      await ref.read(workspaceRepositoryProvider).select(workspace);
      ref.read(activeWorkspaceIdProvider.notifier).setWorkspace(workspace.id);
      if (!context.mounted) return;
      context.go(
        workspace.kind == WorkspaceKind.personal
            ? AppRoutes.personalHome
            : AppRoutes.businessHome,
      );
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _createOrganization(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Créer une entreprise'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nom de l’entreprise'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, nameController.text),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty) return;

    try {
      await ref.read(workspaceRepositoryProvider).createOrganization(name);
      ref.invalidate(workspacesProvider);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({required this.workspace, required this.onTap});

  final WorkspaceSummary workspace;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOrganization = workspace.kind == WorkspaceKind.organization;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          child: Icon(
            isOrganization ? Icons.storefront_outlined : Icons.person_outline,
            color: AppColors.primary,
          ),
        ),
        title: Text(workspace.name, style: AppTypography.bodyLarge),
        subtitle: Text(
          isOrganization
              ? 'Rôle : ${workspace.role ?? 'membre'}'
              : 'Espace personnel',
          style: AppTypography.bodySecondary,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            AppSpacing.gapMd,
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
