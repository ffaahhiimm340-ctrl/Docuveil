import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/chips.dart';
import '../widgets/layout.dart';

/// 20 Safety centre: hidden-script scan, ransomware guard, ID numbers in shared places.
/// These are basic-layer features: built and shown, but not claimed as research.
class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  bool _guard = true;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Safety centre',
      backTo: '/settings',
      children: [
        AppCard(
          borderColor: AppColors.warnBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(Icons.shield_outlined, tone: Tone.look),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hidden-script scan', style: AppText.t3),
                        Text(
                          'Checked 24 new files today',
                          style: AppText.small,
                        ),
                      ],
                    ),
                  ),
                  const StatusChip('1 held', tone: Tone.look, compact: true),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offer_Letter.docm', style: AppText.bodyBold),
                    const PathText('Phone / Download / Offer_Letter.docm'),
                    Text(
                      'Contains a hidden macro. Moved to quarantine.',
                      style: AppText.small,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      'Delete it',
                      danger: true,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton.secondary(
                      'Keep it held',
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconTile(Icons.laptop_rounded, tone: Tone.ok),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ransomware guard', style: AppText.t3),
                        Text('Windows laptop only', style: AppText.small),
                      ],
                    ),
                  ),
                  Switch(
                    value: _guard,
                    onChanged: (v) => setState(() => _guard = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Watching 3 decoy files. If many files change at once, we warn you and pause syncing.',
                style: AppText.sub,
              ),
              const SizedBox(height: 4),
              const PathText(r'C:\Users\Asha\Documents\.docuveil-decoys'),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: StatusChip('No problems found', tone: Tone.ok),
              ),
            ],
          ),
        ),
        AppCard(
          borderColor: AppColors.warnBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(Icons.info_outline_rounded, tone: Tone.look),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID numbers in shared places', style: AppText.t3),
                        Text('1 warning', style: AppText.small),
                      ],
                    ),
                  ),
                  const StatusChip('Review', tone: Tone.look, compact: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'An Aadhaar-style number was found in a scan that other people can open.',
                style: AppText.sub,
              ),
              const PathText(
                'Google Drive / Shared with family / scan_0412.jpg',
              ),
              const SizedBox(height: 10),
              AppButton.secondary('Stop sharing this file', onPressed: () {}),
            ],
          ),
        ),
      ],
    );
  }
}
