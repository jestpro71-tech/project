import 'package:flutter/material.dart';

extension ColorBrightness on Color {
  /// Darkens the color by the given [amount].
  /// The [amount] should be between 0.0 and 1.0.
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}