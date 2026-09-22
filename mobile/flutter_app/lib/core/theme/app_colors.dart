import 'package:flutter/material.dart';

/// DEFACT FACILE brand palette. Screens must use these tokens instead of
/// embedding color values in individual widgets.
abstract final class AppColors {
  static const Color primary = Color(0xFF6657E8);
  static const Color primaryDark = Color(0xFF4D3CC7);
  static const Color accent = Color(0xFF38C9B7);

  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF737A86);

  static const Color success = Color(0xFF2E9C61);
  static const Color warning = Color(0xFFE5A000);
  static const Color error = Color(0xFFE05A67);

  static const Color primarySoft = Color(0xFFE8E5FF);
  static const Color accentSoft = Color(0xFFE0F8F4);
  static const Color successSoft = Color(0xFFE2F4EA);
  static const Color warningSoft = Color(0xFFFFF3D4);
  static const Color errorSoft = Color(0xFFFCE5E8);

  static const Color border = Color(0xFFD8DEE8);
  static const Color divider = Color(0xFFECEFF5);
  static const Color disabled = Color(0xFFB7BEC9);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = Color(0xFF14201B);
}
