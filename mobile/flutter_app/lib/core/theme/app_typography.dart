import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Inter type scale (ui-ux/01-brand/typography.md):
/// Display 32/700, H1 28/700, H2 24/700, H3 20/600, body 14–16/400,
/// caption 12/500, button 14/600.
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    double? height,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  static final TextStyle display = _inter(
    size: 32,
    weight: FontWeight.w700,
    height: 1.2,
  );
  static final TextStyle h1 = _inter(
    size: 28,
    weight: FontWeight.w700,
    height: 1.25,
  );
  static final TextStyle h2 = _inter(
    size: 24,
    weight: FontWeight.w700,
    height: 1.3,
  );
  static final TextStyle h3 = _inter(
    size: 20,
    weight: FontWeight.w600,
    height: 1.3,
  );
  static final TextStyle bodyLarge = _inter(
    size: 16,
    weight: FontWeight.w400,
    height: 1.5,
  );
  static final TextStyle body = _inter(
    size: 14,
    weight: FontWeight.w400,
    height: 1.5,
  );
  static final TextStyle bodySecondary = _inter(
    size: 14,
    weight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );
  static final TextStyle caption = _inter(
    size: 12,
    weight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );
  static final TextStyle button = _inter(
    size: 14,
    weight: FontWeight.w600,
    height: 1.2,
  );
  static final TextStyle amount = _inter(
    size: 20,
    weight: FontWeight.w700,
    height: 1.2,
  );

  static TextTheme textTheme() {
    return TextTheme(
      displayLarge: display,
      headlineLarge: h1,
      headlineMedium: h2,
      headlineSmall: h3,
      titleLarge: h3,
      titleMedium: _inter(size: 16, weight: FontWeight.w600),
      titleSmall: _inter(size: 14, weight: FontWeight.w600),
      bodyLarge: bodyLarge,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: button,
      labelMedium: _inter(size: 12, weight: FontWeight.w600),
      labelSmall: _inter(
        size: 11,
        weight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }
}
