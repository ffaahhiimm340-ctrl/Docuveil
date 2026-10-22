import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// A status word with an icon and a colour. All three together, never colour alone.
class StatusChip extends StatelessWidget {
  const StatusChip(
    this.text, {
    super.key,
    this.tone = Tone.ok,
    this.icon,
    this.compact = false,
  });

  final String text;
  final Tone tone;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final showIcon = icon ?? tone.icon;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(showIcon, size: compact ? 14 : 18, color: tone.fg),
          SizedBox(width: compact ? 4 : 6),
          Flexible(
            child: Text(
              text,
              style: AppText.smallBold.copyWith(
                color: tone.fg,
                fontSize: compact ? 13 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small label saying where a copy lives, e.g. "Laptop · original".
class LocChip extends StatelessWidget {
  const LocChip(this.text, {super.key, this.tone = Tone.brand});

  /// Chip for one copy of a paper.
  LocChip.forCopy(PaperCopy copy, {Key? key, bool withState = true})
    : this(
        key: key,
        withState
            ? '${_short(copy)} · ${copy.state.label.toLowerCase()}'
            : _short(copy),
        tone: copy.state.tone,
      );

  static String _short(PaperCopy c) => switch (c.kind) {
    PlaceKind.phone => 'Phone',
    PlaceKind.laptop => 'Laptop',
    PlaceKind.cloud => c.placeName,
  };

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: AppText.smallBold.copyWith(color: tone.fg, fontSize: 14),
      ),
    );
  }
}

/// Square icon tile used for places, features and settings rows.
class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.tone = Tone.brand,
    this.size = 48,
    this.circle = false,
  });

  final IconData icon;
  final Tone tone;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(circle ? size : 14),
      ),
      child: Icon(icon, color: tone.fg, size: size * 0.5),
    );
  }
}
