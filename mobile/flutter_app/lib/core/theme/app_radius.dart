import 'package:flutter/widgets.dart';

/// Radius scale: 6 / 10 / 14 / 16 / 20 / pill.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;

  static const BorderRadius chip = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius button = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius field = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
  static const BorderRadius badge = BorderRadius.all(Radius.circular(pill));
}
