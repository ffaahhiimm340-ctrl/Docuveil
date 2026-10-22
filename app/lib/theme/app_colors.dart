import 'package:flutter/material.dart';

/// Design A palette (see docs/design). Every status colour is always paired
/// with an icon shape and a word, so colour is never the only signal.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF10213A);
  static const ink2 = Color(0xFF44546A);
  static const line = Color(0xFFD5DEE8);
  static const bg = Color(0xFFEEF2F6);
  static const card = Colors.white;

  static const brand = Color(0xFF2D3FA0);
  static const brandTint = Color(0xFFE8EAFB);

  static const safe = Color(0xFF0B7A5A);
  static const safeTint = Color(0xFFDDF3EA);

  static const warn = Color(0xFF8A5A00);
  static const warnTint = Color(0xFFFCEFD0);
  static const warnRing = Color(0xFFB7791F);
  static const warnBorder = Color(0xFFE5C77A);

  static const bad = Color(0xFFB3261E);
  static const badTint = Color(0xFFFBE3E0);
}

/// Meaning of a chip, tile or line. Used everywhere instead of raw colours.
enum Tone { ok, look, bad, brand, gray }

extension ToneColors on Tone {
  Color get fg => switch (this) {
    Tone.ok => AppColors.safe,
    Tone.look => AppColors.warn,
    Tone.bad => AppColors.bad,
    Tone.brand => AppColors.brand,
    Tone.gray => AppColors.ink2,
  };

  Color get bg => switch (this) {
    Tone.ok => AppColors.safeTint,
    Tone.look => AppColors.warnTint,
    Tone.bad => AppColors.badTint,
    Tone.brand => AppColors.brandTint,
    Tone.gray => AppColors.bg,
  };

  IconData get icon => switch (this) {
    Tone.ok => Icons.check_circle_outline_rounded,
    Tone.look => Icons.warning_amber_rounded,
    Tone.bad => Icons.dangerous_outlined,
    Tone.brand => Icons.info_outline_rounded,
    Tone.gray => Icons.info_outline_rounded,
  };
}
