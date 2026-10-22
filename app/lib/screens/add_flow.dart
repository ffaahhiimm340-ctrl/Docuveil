import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/chips.dart';
import '../widgets/layout.dart';
import '../widgets/seal_ring.dart';

Widget _step(String text) => Text(text, style: AppText.smallBold);

/// 07 Add a paper, step 1: what kind of paper, and where is it right now.
class AddSourceScreen extends StatefulWidget {
  const AddSourceScreen({super.key});

  @override
  State<AddSourceScreen> createState() => _AddSourceScreenState();
}

class _AddSourceScreenState extends State<AddSourceScreen> {
  static const _types = [
    'Aadhaar-style ID',
    'PAN-style card',
    'Marksheet',
    'Insurance policy',
    'Certificate',
  ];
  String _type = 'Marksheet';

  @override
  Widget build(BuildContext context) {
    Widget source(IconData icon, String title, String sub) => AppCard(
      onTap: () => context.go('/add/check'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconTile(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.t3),
                Text(sub, style: AppText.small),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink2),
        ],
      ),
    );

    return PageScaffold(
      title: 'Add a paper',
      backTo: '/',
      trailing: _step('Step 1 of 3'),
      bottom: [
        AppButton.secondary(
          'Just check a file, do not save it',
          onPressed: () => context.go('/check-file'),
        ),
      ],
      children: [
        Text('What kind of paper is it?', style: AppText.t3),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _types)
              OptionPill(
                t,
                selected: t == _type,
                onTap: () => setState(() => _type = t),
              ),
          ],
        ),
        Text('Where is it right now?', style: AppText.t3),
        source(
          Icons.photo_camera_outlined,
          'Scan with the camera',
          'Best for paper you hold',
        ),
        source(
          Icons.smartphone_rounded,
          'A file on this phone',
          'Downloads, Documents, WhatsApp',
        ),
        source(
          Icons.cloud_outlined,
          'From Google Drive',
          'asha.verma@example.com',
        ),
        source(
          Icons.laptop_rounded,
          "From Asha's laptop",
          'Online now, pick a folder',
        ),
      ],
    );
  }
}

/// 08 Add a paper, step 2: check what we read before it becomes the original.
class AddCheckScreen extends StatelessWidget {
  const AddCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget field(String label, String value, {bool warn = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.bodyBold),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: value,
                style: AppText.t3.copyWith(fontWeight: FontWeight.w400),
                decoration: warn
                    ? InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppColors.warnBorder,
                            width: 2,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: warn ? 'Please check' : 'Looks right',
              child: Icon(
                warn
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: warn ? AppColors.warn : AppColors.safe,
                size: 28,
              ),
            ),
          ],
        ),
        if (warn) ...[
          const SizedBox(height: 4),
          Text(
            'The scan was blurry here. Please check it.',
            style: AppText.smallBold.copyWith(color: AppColors.warn),
          ),
        ],
      ],
    );

    return PageScaffold(
      title: 'Add a paper',
      backTo: '/add',
      trailing: _step('Step 2 of 3'),
      bottom: [
        AppButton.primary(
          'Looks right, save it',
          onPressed: () => context.go('/add/saved'),
        ),
        AppButton.text('Scan again', onPressed: () => context.go('/add')),
      ],
      children: [
        AppCard(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC5CBF3), width: 2),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marksheet, Semester 2', style: AppText.t3),
                    const PathText('Phone / Download / Marksheet_Sem2.pdf'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text('Is this what we read?', style: AppText.t2),
        Text(
          'Fix anything that looks wrong. This becomes your trusted original.',
          style: AppText.sub,
        ),
        field('Student name', 'Asha Rajesh Verma'),
        field('Date of birth', '14 Jul 2001'),
        field('Roll number', 'MCA23-0412'),
        field('CGPA, Semester 2', '8.74', warn: true),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.brandTint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.smartphone_rounded, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppText.sub.copyWith(color: AppColors.ink),
                    children: [
                      const TextSpan(text: 'Original will be kept on '),
                      TextSpan(
                        text: 'this phone',
                        style: AppText.bodyBold.copyWith(fontSize: 16),
                      ),
                      const TextSpan(text: '. You choose backups next.'),
                    ],
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

/// 09 Add a paper, step 3: saved, and where to keep extra copies.
class AddSavedScreen extends StatefulWidget {
  const AddSavedScreen({super.key});

  @override
  State<AddSavedScreen> createState() => _AddSavedScreenState();
}

class _AddSavedScreenState extends State<AddSavedScreen> {
  bool _laptop = true;
  bool _drive = true;

  String get _score {
    final copies = 1 + (_laptop ? 1 : 0) + (_drive ? 1 : 0);
    return switch (copies) {
      1 => 'Fragile',
      2 => 'Safe',
      _ => 'Very safe',
    };
  }

  @override
  Widget build(BuildContext context) {
    Widget place(
      PlaceKind kind,
      String name,
      String path, {
      required bool on,
      ValueChanged<bool>? onChanged,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconTile(kind.icon, tone: on ? Tone.ok : Tone.brand, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.t3),
                PathText(path),
              ],
            ),
          ),
          if (onChanged == null)
            const StatusChip('Saved', tone: Tone.ok, compact: true)
          else
            Switch(value: on, onChanged: onChanged),
        ],
      ),
    );

    return PageScaffold(
      title: 'Add a paper',
      back: false,
      trailing: _step('Step 3 of 3'),
      bottom: [
        AppButton.primary('Done', onPressed: () => context.go('/')),
        AppButton.secondary(
          'Add another paper',
          onPressed: () => context.go('/add'),
        ),
      ],
      children: [
        Column(
          children: [
            const SealRing(size: 104),
            const SizedBox(height: 8),
            Text(
              'Saved as your original',
              textAlign: TextAlign.center,
              style: AppText.t0,
            ),
            Text(
              'Marksheet, Semester 2. From now on we watch every copy.',
              textAlign: TextAlign.center,
              style: AppText.sub,
            ),
          ],
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keep extra copies safe', style: AppText.t3),
              Text(
                'More copies means a lost phone is not a lost paper.',
                style: AppText.small,
              ),
              const SizedBox(height: 4),
              place(
                PlaceKind.phone,
                'This phone',
                'Documents / Docuveil / Marksheet_Sem2.pdf',
                on: true,
              ),
              const Divider(height: 1, color: AppColors.line),
              place(
                PlaceKind.laptop,
                "Asha's laptop",
                r'C:\Users\Asha\Documents\Docuveil',
                on: _laptop,
                onChanged: (v) => setState(() => _laptop = v),
              ),
              const Divider(height: 1, color: AppColors.line),
              place(
                PlaceKind.cloud,
                'Google Drive',
                'My Drive / Docuveil',
                on: _drive,
                onChanged: (v) => setState(() => _drive = v),
              ),
            ],
          ),
        ),
        InfoBanner(
          tone: _score == 'Fragile' ? Tone.look : Tone.ok,
          child: Text.rich(
            TextSpan(
              style: AppText.body,
              children: [
                const TextSpan(text: 'With these copies this paper scores '),
                TextSpan(text: _score, style: AppText.bodyBold),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
