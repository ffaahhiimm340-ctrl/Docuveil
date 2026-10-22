import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/sample_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/seal_ring.dart';
import 'pin_pad.dart';

/// 03 Unlock: PIN or fingerprint. Any 6 digits opens the vault in this demo.
class UnlockScreen extends StatelessWidget {
  const UnlockScreen({super.key});

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
                PinPad(
                  showFingerprint: true,
                  onComplete: (_) => context.go('/'),
                ),
                const SizedBox(height: 8),
                AppButton.text('I forgot my PIN', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
