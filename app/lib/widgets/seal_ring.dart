import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';

/// The Seal: a ring of pieces, one per detail on the paper. If one detail has
/// changed, only that piece turns red. This is Docuveil's signature element.
class SealRing extends StatelessWidget {
  const SealRing({
    super.key,
    this.size = 56,
    this.status = PaperStatus.safe,
    this.brokenSegment = 2,
    this.warnSegment,
    this.mark = true,
    this.baseColor,
    this.segments = 6,
  });

  /// Convenience for a paper.
  SealRing.forPaper(Paper paper, {Key? key, double size = 56, bool mark = true})
    : this(
        key: key,
        size: size,
        status: paper.status,
        brokenSegment: paper.brokenSegment,
        warnSegment: paper.sealWarnSegment,
        mark: mark,
      );

  final double size;
  final PaperStatus status;
  final int brokenSegment;
  final int? warnSegment;
  final bool mark;
  final Color? baseColor;
  final int segments;

  String get _label => switch (status) {
    PaperStatus.safe => 'Seal: every detail matches your original',
    PaperStatus.look => 'Seal: worth a look',
    PaperStatus.changed => 'Seal: one detail changed',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _label,
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _SealPainter(
            status: status,
            brokenSegment: brokenSegment,
            warnSegment: warnSegment,
            mark: mark,
            baseColor: baseColor ?? AppColors.safe,
            segments: segments,
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({
    required this.status,
    required this.brokenSegment,
    required this.warnSegment,
    required this.mark,
    required this.baseColor,
    required this.segments,
  });

  final PaperStatus status;
  final int brokenSegment;
  final int? warnSegment;
  final bool mark;
  final Color baseColor;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 26 * s;
    // Thicker stroke on small rings so the pieces stay visible.
    final stroke = (size.width < 60 ? 7 : 6) * s;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final piece = 2 * math.pi / segments;
    final gap = 4.03 / 163.4 * 2 * math.pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < segments; i++) {
      Color color = baseColor;
      if (status == PaperStatus.changed && i == brokenSegment) {
        color = AppColors.bad;
      }
      if (status == PaperStatus.look &&
          warnSegment != null &&
          i == warnSegment) {
        color = AppColors.warnRing;
      }
      paint.color = color;
      canvas.drawArc(rect, -math.pi / 2 + i * piece, piece - gap, false, paint);
    }

    if (!mark) return;

    final glyph = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (status == PaperStatus.safe) {
      glyph
        ..color = baseColor
        ..strokeWidth = 4.5 * s;
      final p = Path()
        ..moveTo(23 * s, 32.5 * s)
        ..relativeLineTo(6 * s, 6 * s)
        ..relativeLineTo(12 * s, -13 * s);
      canvas.drawPath(p, glyph);
    } else {
      final c = status == PaperStatus.changed ? AppColors.bad : AppColors.warn;
      glyph
        ..color = c
        ..strokeWidth = 5 * s;
      canvas.drawLine(Offset(32 * s, 22 * s), Offset(32 * s, 35 * s), glyph);
      canvas.drawLine(Offset(32 * s, 42.5 * s), Offset(32 * s, 43 * s), glyph);
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.status != status ||
      old.brokenSegment != brokenSegment ||
      old.warnSegment != warnSegment ||
      old.mark != mark ||
      old.baseColor != baseColor ||
      old.segments != segments;
}
