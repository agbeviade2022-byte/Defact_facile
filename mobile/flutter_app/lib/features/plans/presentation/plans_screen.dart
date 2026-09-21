import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/plan_repository.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(plansProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Forfaits')),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _PlansError(
          message: error is ApiException
              ? error.message
              : 'Erreur de chargement.',
          onRetry: () => ref.invalidate(plansProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(plansProvider.future),
          child: ListView.separated(
            padding: AppSpacing.screen,
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => AppSpacing.gapMd,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choisissez le bon rythme', style: AppTypography.h1),
                    AppSpacing.gapSm,
                    Text(
                      'Comparez les forfaits et lancez le paiement sécurisé de votre espace.',
                      style: AppTypography.bodySecondary,
                    ),
                  ],
                );
              }
              return _PlanCard(
                plan: items[index - 1],
                onSubscribe: () =>
                    _startSubscription(context, ref, items[index - 1]),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _startSubscription(
    BuildContext context,
    WidgetRef ref,
    PlanSummary plan,
  ) async {
    final cycle = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: AppSpacing.screen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choisir une fréquence', style: AppTypography.h3),
              AppSpacing.gapSm,
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, 'MONTHLY'),
                child: Text(
                  '${_formatAmount(plan.priceMonthly)} ${plan.currency}/mois',
                ),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext, 'YEARLY'),
                child: Text(
                  '${_formatAmount(plan.priceYearly)} ${plan.currency}/an',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (cycle == null || !context.mounted) return;

    try {
      final checkout = await ref
          .read(planRepositoryProvider)
          .startSubscription(planId: plan.id, billingCycle: cycle);
      if (!context.mounted) return;
      await _showCheckout(context, checkout);
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showCheckout(
    BuildContext context,
    SubscriptionCheckout checkout,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paiement prêt'),
        content: SelectableText(
          'Ouvre ce lien pour payer :\n\n${checkout.checkoutUrl}',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: checkout.checkoutUrl),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Copier le lien'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  static String _formatAmount(double amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ' ');
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onSubscribe});

  final PlanSummary plan;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final isFree = plan.priceMonthly == 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(plan.name, style: AppTypography.h2)),
                if (isFree) _PlanLabel(label: 'Démarrage'),
              ],
            ),
            if (plan.description case final description?) ...[
              AppSpacing.gapSm,
              Text(description, style: AppTypography.bodySecondary),
            ],
            AppSpacing.gapMd,
            Text(
              isFree
                  ? 'Gratuit'
                  : '${_formatAmount(plan.priceMonthly)} ${plan.currency}/mois',
              style: AppTypography.amount,
            ),
            if (!isFree)
              Text(
                '${_formatAmount(plan.priceYearly)} ${plan.currency}/an',
                style: AppTypography.caption,
              ),
            AppSpacing.gapMd,
            _PlanDetail(
              icon: Icons.auto_awesome_outlined,
              text:
                  '${_formatInteger(plan.aiCreditsMonthly)} crédits IA par mois',
            ),
            if (plan.limits['members'] case final members?) ...[
              AppSpacing.gapSm,
              _PlanDetail(
                icon: Icons.group_outlined,
                text: members == null
                    ? 'Membres illimités'
                    : '$members membre(s)',
              ),
            ],
            if (!isFree) ...[
              AppSpacing.gapMd,
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onSubscribe,
                  child: const Text('Choisir ce forfait'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ' ');

  String _formatInteger(int amount) => amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ' ',
  );
}

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: AppTypography.body)),
      ],
    );
  }
}

class _PlanLabel extends StatelessWidget {
  const _PlanLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}

class _PlansError extends StatelessWidget {
  const _PlansError({required this.message, required this.onRetry});

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
