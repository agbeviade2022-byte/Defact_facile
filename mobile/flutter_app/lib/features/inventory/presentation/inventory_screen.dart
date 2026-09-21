import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/inventory_repository.dart';

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    final stock = ref.watch(stockProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            onPressed: () => _openProduct(context, ref),
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau produit',
          ),
        ],
      ),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _InventoryError(
          message: error is ApiException
              ? error.message
              : 'Erreur de chargement.',
          onRetry: () {
            ref.invalidate(productsProvider);
            ref.invalidate(stockProvider);
          },
        ),
        data: (items) {
          final levels = stock.asData?.value ?? const <StockSummary>[];
          final levelByProduct = {
            for (final level in levels) level.productId: level,
          };
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productsProvider);
              ref.invalidate(stockProvider);
              await Future.wait([
                ref.read(productsProvider.future),
                ref.read(stockProvider.future),
              ]);
            },
            child: items.isEmpty
                ? ListView(
                    padding: AppSpacing.screen,
                    children: const [
                      SizedBox(height: 96),
                      Icon(Icons.inventory_2_outlined, size: 56),
                      SizedBox(height: AppSpacing.md),
                      Center(child: Text('Aucun produit enregistré.')),
                    ],
                  )
                : ListView.separated(
                    padding: AppSpacing.screen,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => AppSpacing.gapSm,
                    itemBuilder: (_, index) {
                      final product = items[index];
                      final level = levelByProduct[product.id];
                      return Card(
                        child: ListTile(
                          onTap: product.trackStock
                              ? () => _openMovement(context, ref, product)
                              : null,
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2_outlined),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            product.trackStock
                                ? 'Stock : ${(level?.quantity ?? 0).toStringAsFixed(3)} ${product.unit}'
                                : 'Service ou stock désactivé',
                          ),
                          trailing: Text(
                            '${product.salePrice.toStringAsFixed(0)} XOF',
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProduct(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau produit'),
      ),
    );
  }

  Future<void> _openProduct(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateProductSheet(),
    );
    if (created == true) ref.invalidate(productsProvider);
  }

  Future<void> _openMovement(
    BuildContext context,
    WidgetRef ref,
    ProductSummary product,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StockMovementSheet(product: product),
    );
    if (changed == true) ref.invalidate(stockProvider);
  }
}

class _CreateProductSheet extends ConsumerStatefulWidget {
  const _CreateProductSheet();

  @override
  ConsumerState<_CreateProductSheet> createState() =>
      _CreateProductSheetState();
}

class _CreateProductSheetState extends ConsumerState<_CreateProductSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController(text: '0');
  bool _trackStock = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Nouveau produit',
      error: _error,
      saving: _saving,
      children: [
        TextField(
          controller: _name,
          enabled: !_saving,
          decoration: const InputDecoration(labelText: 'Nom'),
        ),
        AppSpacing.gapSm,
        TextField(
          controller: _price,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Prix de vente'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _trackStock,
          title: const Text('Suivre le stock'),
          onChanged: _saving
              ? null
              : (value) => setState(() => _trackStock = value),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Création…' : 'Créer le produit'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;
    if (name.length < 2 || price < 0) {
      setState(() => _error = 'Saisis un nom et un prix valides.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .createProduct(name: name, trackStock: _trackStock, salePrice: price);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de créer le produit.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StockMovementSheet extends ConsumerStatefulWidget {
  const _StockMovementSheet({required this.product});

  final ProductSummary product;

  @override
  ConsumerState<_StockMovementSheet> createState() =>
      _StockMovementSheetState();
}

class _StockMovementSheetState extends ConsumerState<_StockMovementSheet> {
  final _quantity = TextEditingController();
  String _type = 'PURCHASE';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Mouvement de stock',
      error: _error,
      saving: _saving,
      children: [
        Text(
          widget.product.name,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w700),
        ),
        AppSpacing.gapSm,
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: const [
            DropdownMenuItem(value: 'PURCHASE', child: Text('Entrée')),
            DropdownMenuItem(
              value: 'ADJUSTMENT',
              child: Text('Ajustement (+/-)'),
            ),
            DropdownMenuItem(value: 'RETURN', child: Text('Retour')),
          ],
          onChanged: _saving ? null : (value) => setState(() => _type = value!),
        ),
        AppSpacing.gapSm,
        TextField(
          controller: _quantity,
          enabled: !_saving,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(labelText: 'Quantité'),
        ),
        AppSpacing.gapMd,
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final quantity = double.tryParse(_quantity.text.replaceAll(',', '.'));
    if (quantity == null || quantity == 0) {
      setState(() => _error = 'Saisis une quantité différente de zéro.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .adjustStock(
            productId: widget.product.id,
            quantity: quantity,
            type: _type,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible d’enregistrer le mouvement.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.children,
    required this.saving,
    required this.error,
  });

  final String title;
  final List<Widget> children;
  final bool saving;
  final String? error;

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
            Text(title, style: AppTypography.h2),
            AppSpacing.gapMd,
            ...children,
            if (error != null) ...[
              AppSpacing.gapSm,
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InventoryError extends StatelessWidget {
  const _InventoryError({required this.message, required this.onRetry});

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
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
