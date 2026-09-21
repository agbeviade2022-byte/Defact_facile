import 'package:flutter/material.dart';

/// Brand palette (ui-ux/01-brand/colors.md). Screens must never use raw
/// hex values; always go through these tokens or [Theme.of(context)].
abstract final class AppColors {
  static const Color primary = Color(0xFF0B6B4F);
  static const Color primaryDark = Color(0xFF07513C);
  static const Color accent = Color(0xFFF4B740);

  static const Color background = Color(0xFFF7F9F8);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF14201B);
  static const Color textSecondary = Color(0xFF5E6B65);

  static const Color success = Color(0xFF168A5A);
  static const Color warning = Color(0xFFD98A00);
  static const Color error = Color(0xFFD64545);

  // Derived tints used by badges, banners and surfaces.
  static const Color primarySoft = Color(0xFFE3F1EC);
  static const Color accentSoft = Color(0xFFFDF1D6);
  static const Color successSoft = Color(0xFFE0F3EA);
  static const Color warningSoft = Color(0xFFFBEEDA);
  static const Color errorSoft = Color(0xFFFBE3E3);

  static const Color border = Color(0xFFE1E7E4);
  static const Color divider = Color(0xFFEDF1EF);
  static const Color disabled = Color(0xFFB7C1BC);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onAccent = Color(0xFF14201B);
}
