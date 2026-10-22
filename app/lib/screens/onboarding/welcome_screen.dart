import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../widgets/chips.dart';
import '../../widgets/seal_ring.dart';

/// 01 Welcome: what Docuveil does in four plain sentences.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
                    children: [
                      const Center(
                        child: SealRing(size: 120, baseColor: AppColors.brand),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Docuveil',
                        textAlign: TextAlign.center,
                        style: AppText.t0.copyWith(fontSize: 32),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep your important papers safe, and know the moment one changes.',
                        textAlign: TextAlign.center,
                        style: AppText.sub.copyWith(fontSize: 19),
                      ),
                      const SizedBox(height: 20),
                      const ListGroup(
                        children: [
                          RowTile(
                            leading: IconTile(
                              Icons.check_circle_outline_rounded,
                            ),
                            title: 'We watch your papers',
                            subtitle: 'On your phone, laptop and cloud.',
                          ),
                          RowTile(
                            leading: IconTile(Icons.warning_amber_rounded),
                            title: 'We tell you what changed',
                            subtitle: 'The exact detail, before and after.',
                          ),
                          RowTile(
                            leading: IconTile(Icons.verified_user_outlined),
                            title: 'We check before you apply',
                            subtitle: 'Do all your papers agree?',
                          ),
                          RowTile(
                            leading: IconTile(Icons.lock_outline_rounded),
                            title: 'Private by design',
                            subtitle: 'Your papers never leave your devices.',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    children: [
                      AppButton.primary(
                        'Get started',
                        onPressed: () => context.go('/setup-lock'),
                      ),
                      const SizedBox(height: 4),
                      AppButton.text(
                        'I already have a vault',
                        onPressed: () => context.go('/unlock'),
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
