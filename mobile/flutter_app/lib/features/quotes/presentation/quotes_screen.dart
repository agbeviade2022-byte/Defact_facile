import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/reference_ui.dart';
import '../data/quote_repository.dart';

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(quotesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devis'),
        actions: [
          IconButton(
            onPressed: () => _openCreate(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau devis',
          ),
        ],
      ),
      body: quotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _QuotesError(
          message: error is ApiException
              ? error.message
              : 'Erreur de chargement.',
          onRetry: () => ref.invalidate(quotesProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(quotesProvider.future),
          child: items.isEmpty
              ? ReferenceEmptyState(
                  icon: Icons.description_outlined,
                  title: 'Aucun devis',
                  subtitle: 'Créez votre premier devis pour commencer.',
                  actionLabel: 'Nouveau devis',
                  onAction: () => _openCreate(context, ref),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    120,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => AppSpacing.gapSm,
                  itemBuilder: (_, index) => _QuoteTile(quote: items[index]),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau devis'),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateQuoteSheet(),
    );
    if (created == true) ref.invalidate(quotesProvider);
  }
}

class _QuoteTile extends StatelessWidget {
  const _QuoteTile({required this.quote});

  final QuoteSummary quote;

  @override
  Widget build(BuildContext context) {
    return ReferenceListCard(
      icon: Icons.description_outlined,
      title: quote.number,
      subtitle: '${quote.status} · ${quote.issueDate}',
      trailing: Text(
        '${quote.total.toStringAsFixed(0)} ${quote.currency}',
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CreateQuoteSheet extends ConsumerStatefulWidget {
  const _CreateQuoteSheet();

  @override
  ConsumerState<_CreateQuoteSheet> createState() => _CreateQuoteSheetState();
}

class _CreateQuoteSheetState extends ConsumerState<_CreateQuoteSheet> {
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unitPrice = TextEditingController();
  final _taxRate = TextEditingController(text: '0');
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _taxRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen.left,
        AppSpacing.screen.top,
        AppSpacing.screen.right,
        AppSpacing.screen.bottom + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouveau devis', style: AppTypography.h2),
            AppSpacing.gapMd,
            TextField(
              controller: _description,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Prestation ou produit *',
              ),
            ),
            AppSpacing.gapSm,
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantité *'),
                  ),
                ),
                AppSpacing.gapSm,
                Expanded(
                  child: TextField(
                    controller: _unitPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Prix unitaire *',
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.gapSm,
            TextField(
              controller: _taxRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'TVA (%)'),
            ),
            if (_error case final error?) ...[
              AppSpacing.gapSm,
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            AppSpacing.gapMd,
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Enregistrement...' : 'Enregistrer le devis',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final description = _description.text.trim();
    final quantity = double.tryParse(_quantity.text.replaceAll(',', '.'));
    final unitPrice = double.tryParse(_unitPrice.text.replaceAll(',', '.'));
    final taxRate = double.tryParse(_taxRate.text.replaceAll(',', '.')) ?? 0;
    if (description.length < 2 ||
        quantity == null ||
        quantity <= 0 ||
        unitPrice == null ||
        unitPrice <= 0) {
      setState(
        () => _error = 'Renseignez une ligne valide avec quantité et prix.',
      );
      return;
    }
    if (taxRate < 0) {
      setState(() => _error = 'La TVA ne peut pas être négative.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(quotesRepositoryProvider)
          .create(
            description: description,
            quantity: quantity,
            unitPrice: unitPrice,
            taxRate: taxRate,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QuotesError extends StatelessWidget {
  const _QuotesError({required this.message, required this.onRetry});

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
