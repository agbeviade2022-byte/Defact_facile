import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/team_repository.dart';

class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(teamMembersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Équipe')),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: AppSpacing.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is ApiException
                      ? error.message
                      : 'Impossible de charger l’équipe.',
                  textAlign: TextAlign.center,
                ),
                AppSpacing.gapMd,
                OutlinedButton(
                  onPressed: () => ref.invalidate(teamMembersProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(teamMembersProvider.future),
          child: ListView.separated(
            padding: AppSpacing.screen,
            itemCount: items.length,
            separatorBuilder: (_, _) => AppSpacing.gapSm,
            itemBuilder: (_, index) {
              final member = items[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (member.fullName ?? member.email ?? '?')
                          .substring(0, 1)
                          .toUpperCase(),
                    ),
                  ),
                  title: Text(member.fullName ?? member.email ?? 'Membre'),
                  subtitle: Text(member.email ?? member.status),
                  trailing: Text(
                    member.roleName,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
