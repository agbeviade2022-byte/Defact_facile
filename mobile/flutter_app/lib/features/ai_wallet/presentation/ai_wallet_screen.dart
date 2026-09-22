import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/ai_wallet_repository.dart';

class AiWalletScreen extends ConsumerWidget {
  const AiWalletScreen({super.key});

  static const amounts = [1000, 5000, 10000, 25000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(aiWalletProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet IA')),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _WalletError(
          message: error is ApiException
              ? error.message
              : 'Erreur de chargement.',
          onRetry: () => ref.invalidate(aiWalletProvider),
        ),
        data: (balance) => RefreshIndicator(
          onRefresh: () => ref.refresh(aiWalletProvider.future),
          child: ListView(
            padding: AppSpacing.screen,
            children: [
              Card(
                color: AppColors.primarySoft,
                child: Padding(
                  padding: AppSpacing.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solde disponible',
                        style: AppTypography.bodySecondary,
                      ),
                      AppSpacing.gapSm,
                      Text(
                        '${_format(balance.balance)} crédits',
                        style: AppTypography.display,
                      ),
                      AppSpacing.gapSm,
                      Text(
                        '${_format(balance.lifetimeConsumed)} crédits consommés',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
              ),
              AppSpacing.gapXl,
              Text('Recharger le wallet', style: AppTypography.h2),
              AppSpacing.gapSm,
              Text(
                'Le crédit est ajouté uniquement après confirmation du paiement.',
                style: AppTypography.bodySecondary,
              ),
              AppSpacing.gapMd,
              for (final amount in amounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: OutlinedButton(
                    onPressed: () => _topUp(context, ref, amount),
                    child: Text('${_format(amount)} XOF'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _topUp(BuildContext context, WidgetRef ref, int amount) async {
    try {
      final checkout = await ref
          .read(aiWalletRepositoryProvider)
          .createTopUp(amount);
      if (!context.mounted) return;
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
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  static String _format(int amount) => amount.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ' ',
  );
}

class _WalletError extends StatelessWidget {
  const _WalletError({required this.message, required this.onRetry});

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
