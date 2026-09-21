import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Entry screen. Session restoration will be wired in Mission 02 (auth);
/// for now it forwards to the login route so the routing graph is exercised.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(AppRoutes.login);
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
