import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/pin_lock.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import 'pin_pad.dart';

/// 02 Set up lock: choose a 6-digit PIN and name this device.
class SetLockScreen extends StatefulWidget {
  const SetLockScreen({super.key});

  @override
  State<SetLockScreen> createState() => _SetLockScreenState();
}

class _SetLockScreenState extends State<SetLockScreen> {
  String? _first;
  int _round = 0; // changing the pad's key clears it
  String? _error;

  Future<void> _entered(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
        _round++;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'Those PINs did not match. Choose your PIN again.';
        _round++;
      });
      return;
    }
    await PinLock.setPin(pin);
    if (mounted) context.go('/');
  }

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
                Text(
                  _first == null ? 'Choose a PIN' : 'Enter the same PIN again',
                  style: AppText.bodyBold,
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: AppText.smallBold.copyWith(color: AppColors.bad),
                  ),
                const SizedBox(height: 8),
                PinPad(key: ValueKey(_round), onComplete: _entered),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
