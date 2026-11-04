import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/pin_lock.dart';
import '../../data/sample_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/seal_ring.dart';
import 'pin_pad.dart';

/// 03 Unlock: the PIN opens the vault. If no PIN exists on this device yet,
/// the first one entered becomes the PIN.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  int _round = 0; // changing the pad's key clears it
  String? _error;

  Future<void> _entered(String pin) async {
    if (!PinLock.isSet) {
      await PinLock.setPin(pin);
      if (mounted) context.go('/');
      return;
    }
    final r = await PinLock.tryPin(pin);
    if (!mounted) return;
    if (r == UnlockResult.ok) {
      context.go('/');
      return;
    }
    final wait = PinLock.waitSeconds();
    setState(() {
      _round++;
      _error = wait > 0
          ? 'Too many wrong tries. Wait $wait seconds and try again.'
          : 'That PIN is not right. Try again.';
    });
  }

  void _forgot() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Your PIN is not kept anywhere, so it cannot be recovered. Resetting the vault is not available yet.',
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
              children: [
                const Center(
                  child: SealRing(size: 84, baseColor: AppColors.brand),
                ),
                const SizedBox(height: 10),
                Text(
                  'Welcome back, ${SampleData.userName}',
                  textAlign: TextAlign.center,
                  style: AppText.t0,
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter your PIN to open your vault.',
                  textAlign: TextAlign.center,
                  style: AppText.sub,
                ),
                const SizedBox(height: 22),
                if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppText.smallBold.copyWith(color: AppColors.bad),
                  ),
                  const SizedBox(height: 8),
                ],
                PinPad(key: ValueKey(_round), onComplete: _entered),
                const SizedBox(height: 8),
                AppButton.text('I forgot my PIN', onPressed: _forgot),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
