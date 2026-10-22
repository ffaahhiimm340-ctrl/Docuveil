import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

/// Big PIN entry. Shows progress dots and a 3x4 keypad with 62px keys.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onComplete,
    this.length = 6,
    this.showFingerprint = false,
  });

  final ValueChanged<String> onComplete;
  final int length;
  final bool showFingerprint;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';

  void _add(String d) {
    if (_digits.length >= widget.length) return;
    setState(() => _digits += d);
    if (_digits.length == widget.length) {
      final pin = _digits;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onComplete(pin),
      );
    }
  }

  void _back() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_digits.length} of ${widget.length} digits entered',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _digits.length
                        ? AppColors.brand
                        : Colors.transparent,
                    border: Border.all(
                      color: i < _digits.length
                          ? AppColors.brand
                          : AppColors.line,
                      width: 3,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['fp', '0', 'del'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (final k in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _Key(
                        k,
                        onDigit: _add,
                        onDelete: _back,
                        showFingerprint: widget.showFingerprint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(
    this.k, {
    required this.onDigit,
    required this.onDelete,
    required this.showFingerprint,
  });

  final String k;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final bool showFingerprint;

  @override
  Widget build(BuildContext context) {
    if (k == 'fp' && !showFingerprint) return const SizedBox(height: 60);

    final Widget face = switch (k) {
      'del' => const Icon(
        Icons.backspace_outlined,
        size: 26,
        color: AppColors.ink,
      ),
      'fp' => const Icon(
        Icons.fingerprint_rounded,
        size: 30,
        color: AppColors.brand,
      ),
      _ => Text(k, style: AppText.t0.copyWith(fontSize: 26)),
    };
    final label = switch (k) {
      'del' => 'Delete last digit',
      'fp' => 'Use fingerprint',
      _ => k,
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.line, width: 2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          onTap: () {
            if (k == 'del') {
              onDelete();
            } else if (k != 'fp') {
              onDigit(k);
            }
          },
          child: SizedBox(height: 60, child: Center(child: face)),
        ),
      ),
    );
  }
}
