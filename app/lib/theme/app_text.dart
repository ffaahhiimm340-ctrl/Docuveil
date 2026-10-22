import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type styles from design A: Lexend for headings, Atkinson Hyperlegible
/// (made for low vision) for everything else. Body text is 16px or larger.
class AppText {
  AppText._();

  static TextStyle _lexend(
    double size,
    FontWeight w, {
    Color? color,
    double? height,
    double? spacing,
  }) => GoogleFonts.lexend(
    fontSize: size,
    fontWeight: w,
    color: color ?? AppColors.ink,
    height: height,
    letterSpacing: spacing,
  );

  static TextStyle _body(
    double size,
    FontWeight w, {
    Color? color,
    double? height,
  }) => GoogleFonts.atkinsonHyperlegible(
    fontSize: size,
    fontWeight: w,
    color: color ?? AppColors.ink,
    height: height,
  );

  /// Big screen title, e.g. "Good morning, Asha".
  static TextStyle get t0 =>
      _lexend(26, FontWeight.w600, height: 1.2, spacing: -0.3);
  static TextStyle get t0Wide =>
      _lexend(34, FontWeight.w600, height: 1.15, spacing: -0.4);

  /// Page title in the top bar.
  static TextStyle get t1 => _lexend(22, FontWeight.w600, height: 1.25);

  /// Section heading.
  static TextStyle get t2 => _lexend(20, FontWeight.w600);

  /// Row title.
  static TextStyle get t3 => _body(18, FontWeight.w700);

  static TextStyle get body => _body(17, FontWeight.w400, height: 1.4);
  static TextStyle get bodyBold => _body(17, FontWeight.w700, height: 1.4);

  /// Secondary sentence under a title.
  static TextStyle get sub =>
      _body(16, FontWeight.w400, color: AppColors.ink2, height: 1.4);
  static TextStyle get small =>
      _body(15, FontWeight.w400, color: AppColors.ink2);
  static TextStyle get smallBold =>
      _body(15, FontWeight.w700, color: AppColors.ink2);

  static TextStyle get button => _body(18, FontWeight.w700);

  /// File paths are shown in a monospace face so they are easy to read exactly.
  static TextStyle get path => const TextStyle(
    fontFamily: 'Consolas',
    fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
    fontSize: 13.5,
    height: 1.35,
    color: AppColors.ink2,
  );

  /// Large numbers such as CGPA values.
  static TextStyle num(double size, {Color? color}) =>
      _lexend(size, FontWeight.w600, color: color);
}
