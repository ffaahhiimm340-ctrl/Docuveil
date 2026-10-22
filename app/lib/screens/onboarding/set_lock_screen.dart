import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import 'pin_pad.dart';

/// 02 Set up lock: choose a 6-digit PIN and name this device.
class SetLockScreen extends StatefulWidget {
  const SetLockScreen({super.key});

  @override
  State<SetLockScreen> createState() => _SetLockScreenState();
}

class _SetLockScreenState extends State<SetLockScreen> {
  bool _fingerprint = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Row(
                  children: [
                    Material(
                      color: AppColors.card,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.go('/welcome'),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Lock your vault', style: AppText.t1)),
                    Text('Step 1 of 2', style: AppText.smallBold),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a 6-digit PIN. It stays on this device and is never sent anywhere.',
                  style: AppText.sub,
                ),
                const SizedBox(height: 14),
                Text('Name this device', style: AppText.bodyBold),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: "Asha's phone",
                  style: AppText.t3.copyWith(fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 18),
                PinPad(onComplete: (_) => context.go('/')),
                const SizedBox(height: 6),
                AppCard(
                  child: Row(
                    children: [
                      const IconTile(Icons.fingerprint_rounded),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Also use fingerprint', style: AppText.t3),
                            Text(
                              'Open faster next time.',
                              style: AppText.small,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _fingerprint,
                        onChanged: (v) => setState(() => _fingerprint = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
