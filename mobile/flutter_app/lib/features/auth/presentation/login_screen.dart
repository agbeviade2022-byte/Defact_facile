import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Layout-only login screen. Email OTP + Google OAuth are implemented in
/// Mission 02; the buttons currently route to the workspace selector so the
/// navigation graph can be validated end to end.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                  const TextField(
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: [AutofillHints.email],
                    decoration: InputDecoration(labelText: 'Adresse e-mail'),
                  ),
                  AppSpacing.gapMd,
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.workspaces),
                    child: const Text('Continuer'),
                  ),
                  AppSpacing.gapMd,
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.workspaces),
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
