import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(accessTokenProvider.notifier).restore();
      final hasSession =
          ref.read(accessTokenProvider) != null ||
          (supabaseInitialized &&
              Supabase.instance.client.auth.currentSession != null);
      if (mounted) {
        context.go(hasSession ? AppRoutes.workspaces : AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConfig.appName,
              style: AppTypography.display.copyWith(color: AppColors.onPrimary),
            ),
            AppSpacing.gapXs,
            Text(
              AppConfig.tagline,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.primarySoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
