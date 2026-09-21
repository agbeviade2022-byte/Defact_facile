import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Saisis une adresse e-mail valide.');
      return;
    }

    final auth = ref.read(authServiceProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        await auth.sendEmailCode(email);
        if (mounted) setState(() => _codeSent = true);
      } else {
        final code = _codeController.text.trim();
        if (code.length < 6) {
          setState(() => _error = 'Saisis le code reçu par e-mail.');
          return;
        }
        await auth.verifyEmailCode(email: email, token: code);
        if (mounted) context.go(AppRoutes.workspaces);
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de se connecter pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    final auth = ref.read(authServiceProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await auth.signInWithGoogle();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Connexion Google impossible.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppConfig.appName,
                    style: AppTypography.h1,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXs,
                  Text(
                    AppConfig.tagline,
                    style: AppTypography.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXxl,
                  TextField(
                    controller: _emailController,
                    enabled: !_codeSent && !_loading,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                    ),
                  ),
                  if (_codeSent) ...[
                    AppSpacing.gapMd,
                    TextField(
                      controller: _codeController,
                      enabled: !_loading,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: 'Code reçu par e-mail',
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    AppSpacing.gapSm,
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (!auth.isConfigured) ...[
                    AppSpacing.gapSm,
                    const Text(
                      'Configure Supabase pour activer la connexion.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                  AppSpacing.gapMd,
                  FilledButton(
                    onPressed: _loading || !auth.isConfigured
                        ? null
                        : _continue,
                    child: Text(
                      _loading
                          ? 'Chargement…'
                          : _codeSent
                          ? 'Vérifier le code'
                          : 'Continuer',
                    ),
                  ),
                  AppSpacing.gapMd,
                  OutlinedButton.icon(
                    onPressed: _loading || !auth.isConfigured ? null : _google,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continuer avec Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
