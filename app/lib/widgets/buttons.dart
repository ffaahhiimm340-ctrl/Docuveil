import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum _Kind { primary, secondary, text }

/// The three button levels from design A: one main action per screen,
/// a second choice, and a quiet text button.
class AppButton extends StatelessWidget {
  const AppButton.primary(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.danger = false,
    this.fit = false,
  }) : _kind = _Kind.primary;
  const AppButton.secondary(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.danger = false,
    this.fit = false,
  }) : _kind = _Kind.secondary;
  const AppButton.text(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.danger = false,
    this.fit = false,
  }) : _kind = _Kind.text;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool danger;

  /// When true the button hugs its text instead of filling the width.
  final bool fit;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.bad : AppColors.brand;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 22), const SizedBox(width: 10)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final Widget button = switch (_kind) {
      _Kind.primary => FilledButton(
        onPressed: onPressed ?? () {},
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: shape,
          textStyle: AppText.button,
        ),
        child: child,
      ),
      _Kind.secondary => OutlinedButton(
        onPressed: onPressed ?? () {},
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: accent,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          side: BorderSide(color: accent, width: 2),
          shape: shape,
          textStyle: AppText.button,
        ),
        child: child,
      ),
      _Kind.text => TextButton(
        onPressed: onPressed ?? () {},
        style: TextButton.styleFrom(
          foregroundColor: danger ? AppColors.bad : AppColors.ink2,
          minimumSize: const Size(0, 48),
          textStyle: AppText.button.copyWith(
            fontSize: 17,
            decoration: TextDecoration.underline,
          ),
        ),
        child: child,
      ),
    };

    return fit
        ? Align(alignment: Alignment.centerLeft, child: button)
        : SizedBox(width: double.infinity, child: button);
  }
}

/// Rounded selectable pill, used for filters and choices.
class OptionPill extends StatelessWidget {
  const OptionPill(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.brand : AppColors.ink;
    return Material(
      color: selected ? AppColors.brandTint : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.brand : AppColors.line,
          width: 2,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap ?? () {},
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppText.bodyBold.copyWith(color: fg, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
