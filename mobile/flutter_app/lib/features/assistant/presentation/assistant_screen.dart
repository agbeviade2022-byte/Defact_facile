import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/assistant_repository.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _promptController = TextEditingController();
  AiAnswer? _answer;
  ApiException? _error;
  bool _loading = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant IA')),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          Text(
            'Une aide concrète pour votre activité',
            style: AppTypography.h1,
          ),
          AppSpacing.gapSm,
          Text(
            'Posez une question sur votre gestion. Chaque réponse consomme les crédits de votre wallet.',
            style: AppTypography.bodySecondary,
          ),
          AppSpacing.gapLg,
          TextField(
            controller: _promptController,
            minLines: 4,
            maxLines: 8,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Votre question',
              hintText:
                  'Ex. Comment relancer un client en retard de paiement ?',
              alignLabelWithHint: true,
            ),
          ),
          AppSpacing.gapMd,
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _ask,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _loading ? 'Réponse en cours...' : 'Demander à l’assistant',
              ),
            ),
          ),
          if (_error case final error?) ...[
            AppSpacing.gapMd,
            Text(
              error.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_answer case final answer?) ...[
            AppSpacing.gapXl,
            Text('Réponse', style: AppTypography.h2),
            AppSpacing.gapSm,
            Card(
              child: Padding(
                padding: AppSpacing.card,
                child: SelectableText(answer.text),
              ),
            ),
            AppSpacing.gapSm,
            Text(
              '${answer.provider} · ${answer.model}',
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _ask() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _error = const ApiException(
          statusCode: 400,
          message: 'Saisissez une question avant de continuer.',
        );
        _answer = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
    });
    try {
      final answer = await ref.read(assistantRepositoryProvider).ask(prompt);
      if (!mounted) return;
      setState(() => _answer = answer);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
