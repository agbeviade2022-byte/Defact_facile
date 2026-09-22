import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/reference_ui.dart';
import '../data/customer_repository.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final filtered = customers.asData?.value.where((customer) {
      final query = _query.toLowerCase();
      return customer.name.toLowerCase().contains(query) ||
          (customer.email?.toLowerCase().contains(query) ?? false) ||
          (customer.phone?.toLowerCase().contains(query) ?? false) ||
          (customer.city?.toLowerCase().contains(query) ?? false);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            onPressed: () => _openCreate(context),
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Ajouter un client',
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
              hintText: 'Rechercher un client',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _CustomersError(
                message: error is ApiException
                    ? error.message
                    : 'Erreur de chargement.',
                onRetry: () => ref.invalidate(customersProvider),
              ),
              data: (_) => RefreshIndicator(
                onRefresh: () => ref.refresh(customersProvider.future),
                child: filtered!.isEmpty
                    ? ReferenceEmptyState(
                        icon: Icons.people_outline,
                        title: 'Aucun client',
                        subtitle:
                            'Ajoutez votre premier client pour commencer.',
                        actionLabel: 'Nouveau client',
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
                        itemBuilder: (_, index) =>
                            _CustomerTile(customer: filtered[index]),
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nouveau client'),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateCustomerSheet(),
    );
    if (created == true) ref.invalidate(customersProvider);
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});

  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) {
    final detail = [
      customer.email,
      customer.phone,
      customer.city,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return ReferenceListCard(
      icon: customer.type == 'COMPANY'
          ? Icons.business_outlined
          : Icons.person_outline,
      title: customer.name,
      subtitle: detail.isEmpty ? null : detail,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _CreateCustomerSheet extends ConsumerStatefulWidget {
  const _CreateCustomerSheet();

  @override
  ConsumerState<_CreateCustomerSheet> createState() =>
      _CreateCustomerSheetState();
}

class _CreateCustomerSheetState extends ConsumerState<_CreateCustomerSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  String _type = 'INDIVIDUAL';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
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
            Text('Nouveau client', style: AppTypography.h2),
            AppSpacing.gapMd,
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'INDIVIDUAL', label: Text('Particulier')),
                ButtonSegment(value: 'COMPANY', label: Text('Entreprise')),
              ],
              selected: {_type},
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
            AppSpacing.gapMd,
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom *'),
            ),
            AppSpacing.gapSm,
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            AppSpacing.gapSm,
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
            ),
            AppSpacing.gapSm,
            TextField(
              controller: _city,
              decoration: const InputDecoration(labelText: 'Ville'),
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
              child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Saisissez un nom valide.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(customersRepositoryProvider)
          .create(
            type: _type,
            name: name,
            email: _email.text,
            phone: _phone.text,
            city: _city.text,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CustomersError extends StatelessWidget {
  const _CustomersError({required this.message, required this.onRetry});

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
