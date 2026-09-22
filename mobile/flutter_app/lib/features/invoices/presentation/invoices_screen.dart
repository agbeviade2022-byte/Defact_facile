import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/reference_ui.dart';
import '../../payments/data/payment_repository.dart';
import '../../quotes/data/quote_repository.dart';
import '../data/invoice_repository.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);
    final filtered = invoices.asData?.value.where((invoice) {
      final query = _query.toLowerCase();
      return invoice.number.toLowerCase().contains(query) ||
          invoice.status.toLowerCase().contains(query) ||
          invoice.issueDate.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factures'),
        actions: [
          IconButton(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.add),
            tooltip: 'Nouvelle facture',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: ReferenceSearchField(
              hintText: 'Rechercher une facture',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: invoices.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InvoiceError(
                message: error is ApiException
                    ? error.message
                    : 'Erreur de chargement.',
                onRetry: () => ref.invalidate(invoicesProvider),
              ),
              data: (_) => RefreshIndicator(
                onRefresh: () => ref.refresh(invoicesProvider.future),
                child: filtered!.isEmpty
                    ? ReferenceEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aucune facture',
                        subtitle: 'Créez votre première facture en quelques secondes.',
                        actionLabel: 'Nouvelle facture',
                        onAction: () => _openCreate(context),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          120,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => AppSpacing.gapSm,
                        itemBuilder: (_, index) => _InvoiceTile(
                          invoice: filtered[index],
                          onTap: filtered[index].amountDue > 0
                              ? () => _openPayment(context, filtered[index])
                              : null,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle facture'),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateInvoiceSheet(),
    );
    if (created == true) ref.invalidate(invoicesProvider);
  }

  Future<void> _openPayment(
    BuildContext context,
    InvoiceSummary invoice,
  ) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreatePaymentSheet(invoice: invoice),
    );
    if (paid == true) ref.invalidate(invoicesProvider);
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, this.onTap});

  final InvoiceSummary invoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ReferenceListCard(
      icon: Icons.receipt_long_outlined,
      title: invoice.number,
      subtitle:
          '${invoice.status} · ${invoice.issueDate}'
          '${invoice.amountDue > 0 ? ' · Reste ${invoice.amountDue.toStringAsFixed(0)} ${invoice.currency}' : ''}',
      onTap: onTap,
      trailing: Text(
        '${invoice.total.toStringAsFixed(0)} ${invoice.currency}',
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CreatePaymentSheet extends ConsumerStatefulWidget {
  const _CreatePaymentSheet({required this.invoice});

  final InvoiceSummary invoice;

  @override
  ConsumerState<_CreatePaymentSheet> createState() =>
      _CreatePaymentSheetState();
}

class _CreatePaymentSheetState extends ConsumerState<_CreatePaymentSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.invoice.amountDue.toStringAsFixed(0),
  );
  final _reference = TextEditingController();
  String _method = 'CASH';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enregistrer un paiement', style: AppTypography.h2),
          AppSpacing.gapSm,
          Text(
            'Reste : ${widget.invoice.amountDue.toStringAsFixed(0)} ${widget.invoice.currency}',
          ),
          AppSpacing.gapMd,
          TextField(
            controller: _amount,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant'),
          ),
          AppSpacing.gapSm,
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Mode de paiement'),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Espèces')),
              DropdownMenuItem(
                value: 'ORANGE_MONEY',
                child: Text('Orange Money'),
              ),
              DropdownMenuItem(value: 'MTN_MOMO', child: Text('MTN MoMo')),
              DropdownMenuItem(value: 'MOOV_MONEY', child: Text('Moov Money')),
              DropdownMenuItem(value: 'WAVE', child: Text('Wave')),
              DropdownMenuItem(
                value: 'BANK_TRANSFER',
                child: Text('Virement bancaire'),
              ),
              DropdownMenuItem(value: 'CARD', child: Text('Carte')),
              DropdownMenuItem(value: 'OTHER', child: Text('Autre')),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _method = value!),
          ),
          AppSpacing.gapSm,
          TextField(
            controller: _reference,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Référence (optionnel)',
            ),
          ),
          if (_error != null) ...[
            AppSpacing.gapSm,
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          AppSpacing.gapMd,
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0 || amount > widget.invoice.amountDue) {
      setState(
        () => _error = 'Saisis un montant compris entre 0 et le reste dû.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(paymentsRepositoryProvider)
          .createForInvoice(
            invoiceId: widget.invoice.id,
            amount: amount,
            method: _method,
            reference: _reference.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible d’enregistrer le paiement.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CreateInvoiceSheet extends ConsumerStatefulWidget {
  const _CreateInvoiceSheet();

  @override
  ConsumerState<_CreateInvoiceSheet> createState() =>
      _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends ConsumerState<_CreateInvoiceSheet> {
  String? _quoteId;
  String? _error;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(quotesProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen.left,
        AppSpacing.screen.top,
        AppSpacing.screen.right,
        AppSpacing.screen.bottom + bottom,
      ),
      child: SingleChildScrollView(
        child: quotes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            error is ApiException
                ? error.message
                : 'Impossible de charger les devis.',
          ),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Nouvelle facture', style: AppTypography.h2),
              AppSpacing.gapMd,
              DropdownButtonFormField<String>(
                initialValue: _quoteId,
                decoration: const InputDecoration(
                  labelText: 'Devis à convertir',
                ),
                items: items
                    .map(
                      (quote) => DropdownMenuItem(
                        value: quote.id,
                        child: Text(
                          '${quote.number} · ${quote.total.toStringAsFixed(0)} ${quote.currency}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _quoteId = value),
              ),
              if (_error != null) ...[
                AppSpacing.gapSm,
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              AppSpacing.gapMd,
              FilledButton(
                onPressed: _saving || _quoteId == null ? null : _submit,
                child: Text(_saving ? 'Création…' : 'Créer la facture'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(invoicesRepositoryProvider).createFromQuote(_quoteId!);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de créer la facture.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _InvoiceError extends StatelessWidget {
  const _InvoiceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.screen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            AppSpacing.gapMd,
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
