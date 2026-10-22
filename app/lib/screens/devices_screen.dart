import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/sample_data.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/chips.dart';
import '../widgets/layout.dart';

/// 16 Devices and sync.
class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);

    final status = InfoBanner(
      tone: Tone.ok,
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everything is in sync',
            style: AppText.t3.copyWith(color: AppColors.safe),
          ),
          Text('Last check: 2 minutes ago.', style: AppText.body),
        ],
      ),
    );

    final devices = ListGroup(
      children: [
        for (final d in SampleData.devices)
          RowTile(
            leading: IconTile(
              d.kind.icon,
              tone: d.online ? Tone.ok : Tone.look,
            ),
            title: d.name,
            subtitle: d.detail,
            trailing: StatusChip(
              d.online ? 'Online' : 'Offline',
              tone: d.online ? Tone.ok : Tone.look,
              compact: true,
            ),
          ),
      ],
    );

    final clouds = ListGroup(
      children: [
        for (final c in SampleData.clouds)
          RowTile(
            leading: IconTile(
              Icons.cloud_outlined,
              tone: c.connected ? Tone.brand : Tone.gray,
            ),
            title: c.name,
            subtitle: c.account,
            trailing: c.connected
                ? const StatusChip('Connected', tone: Tone.ok, compact: true)
                : const StatusChip('Connect', tone: Tone.brand, compact: true),
          ),
      ],
    );

    final main = <Widget>[
      status,
      Text('My devices', style: AppText.t2),
      devices,
      Text('Cloud accounts', style: AppText.t2),
      clouds,
    ];

    final add = AppCard(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a device', style: AppText.t2),
          const SizedBox(height: 8),
          Text(
            'Scan a code on your other device to link it. Your papers are never sent to our server.',
            style: AppText.sub,
          ),
          const SizedBox(height: 14),
          AppButton.primary(
            'Add a device',
            onPressed: () => context.go('/devices/pair'),
          ),
        ],
      ),
    );

    return PageScaffold(
      title: 'Devices and sync',
      subtitle: wide
          ? 'The phones, laptops and cloud accounts that keep your papers safe.'
          : null,
      backTo: '/settings',
      maxWidth: wide ? 1180 : 640,
      bottom: wide
          ? null
          : [
              AppButton.primary(
                'Add a device',
                onPressed: () => context.go('/devices/pair'),
              ),
            ],
      children: [
        wide
            ? TwoCol(main: main, side: [add], sideWidth: 360)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in main) ...[w, const SizedBox(height: 12)],
                ],
              ),
      ],
    );
  }
}

/// 17 Add a device: pairing code.
class PairScreen extends StatelessWidget {
  const PairScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Add a device',
      backTo: '/devices',
      bottom: [
        AppButton.secondary('Cancel', onPressed: () => context.go('/devices')),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const OptionPill('Phone or tablet', selected: true),
            const OptionPill('Laptop or PC'),
          ],
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text(
                'Scan this code on your other device',
                style: AppText.t3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const _FakeQr(size: 190),
              const SizedBox(height: 10),
              Text('Or type this code:', style: AppText.small),
              Text(
                '482 913',
                style: AppText.num(34).copyWith(letterSpacing: 4),
              ),
              Text('Works for 10 minutes.', style: AppText.small),
            ],
          ),
        ),
        const ListGroup(
          children: [
            _StepRow(1, 'Install Docuveil on the other device.'),
            _StepRow(2, 'Choose "I already have a vault".'),
            _StepRow(3, 'Scan the code or type the number.'),
          ],
        ),
        InfoBanner(
          tone: Tone.brand,
          icon: Icons.lock_outline_rounded,
          child: Text(
            'Your papers are not sent. Only a private key is shared, directly between your devices.',
            style: AppText.sub.copyWith(color: AppColors.ink),
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.n, this.text);
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return RowTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.brandTint,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          '$n',
          style: AppText.bodyBold.copyWith(color: AppColors.brand),
        ),
      ),
      title: text,
    );
  }
}

/// Stand-in for the pairing QR code until the real one is generated.
class _FakeQr extends StatelessWidget {
  const _FakeQr({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Example pairing code',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _QrPainter()),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  static const _on = <(int, int, int, int)>[
    (0, 0, 3, 3),
    (8, 0, 3, 3),
    (0, 8, 3, 3),
    (4, 0, 1, 1),
    (6, 1, 1, 1),
    (4, 2, 1, 1),
    (5, 3, 2, 1),
    (0, 4, 1, 1),
    (2, 4, 2, 1),
    (5, 5, 1, 2),
    (7, 4, 2, 1),
    (9, 5, 2, 1),
    (3, 6, 1, 1),
    (7, 6, 1, 2),
    (9, 7, 1, 1),
    (4, 8, 2, 1),
    (6, 9, 1, 2),
    (8, 9, 1, 1),
    (10, 9, 1, 2),
    (4, 10, 1, 1),
    (1, 5, 1, 1),
    (2, 7, 1, 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 11;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final ink = Paint()..color = AppColors.ink;
    for (final r in _on) {
      canvas.drawRect(
        Rect.fromLTWH(r.$1 * u, r.$2 * u, r.$3 * u, r.$4 * u),
        ink,
      );
    }
    final white = Paint()..color = Colors.white;
    for (final p in const [(1, 1), (9, 1), (1, 9)]) {
      canvas.drawRect(Rect.fromLTWH(p.$1 * u, p.$2 * u, u, u), white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
