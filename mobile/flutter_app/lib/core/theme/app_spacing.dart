import 'package:flutter/widgets.dart';

/// Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 48;
  static const double giant = 64;

  /// Minimum touch target (ui-ux/02-design-system/foundations.md).
  static const double minTouchTarget = 48;

  static const EdgeInsets screen = EdgeInsets.all(md);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: md,
  );
  static const EdgeInsets card = EdgeInsets.all(md);
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );

  static const SizedBox gapXxs = SizedBox(height: xxs, width: xxs);
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);
}
