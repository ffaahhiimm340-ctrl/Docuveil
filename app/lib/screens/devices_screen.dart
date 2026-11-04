import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/sample_data.dart';
import '../data/sync_service.dart';
import '../data/vault.dart';
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

    const status = _SyncCard();

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
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _code = TextEditingController();
  String? _shown;
  String? _error;

  @override
  void initState() {
    super.initState();
    SyncService.instance.secretOrCreate().then((s) {
      if (mounted) setState(() => _shown = s.encode());
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    try {
      await SyncService.instance.join(_code.text);
      if (mounted) context.go('/devices');
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    return PageScaffold(
      title: 'Add a device',
      backTo: '/devices',
      bottom: [
        AppButton.secondary('Cancel', onPressed: () => context.go('/devices')),
      ],
      children: [
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Text(
                'Show this code to your other device',
                style: AppText.t3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (shown == null)
                const SizedBox(
                  height: 190,
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                QrImageView(data: shown, size: 190),
                const SizedBox(height: 10),
                Text('Or copy this code:', style: AppText.small),
                SelectableText(
                  shown,
                  textAlign: TextAlign.center,
                  style: AppText.path,
                ),
                TextButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: shown)),
                  child: const Text('Copy'),
                ),
              ],
              Text(
                'Anyone who gets this code can link to your vault. Do not share it.',
                textAlign: TextAlign.center,
                style: AppText.small,
              ),
            ],
          ),
        ),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Have a code from your other device?', style: AppText.t3),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                decoration: InputDecoration(
                  hintText: 'dv1:...',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 10),
              AppButton.primary('Link this device', onPressed: _join),
            ],
          ),
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

/// Live sync state: relay address, a sync button, and what it found.
class _SyncCard extends StatefulWidget {
  const _SyncCard();

  @override
  State<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<_SyncCard> {
  late final _url = TextEditingController(text: SyncService.instance.relayUrl);
  String? _message;
  bool _bad = false;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _sync() async {
    final sync = SyncService.instance;
    setState(() => _busy = true);
    try {
      await sync.setRelayUrl(_url.text);
      final r = await sync.syncNow(Vault.docs.value);
      setState(() {
        _bad = r.alerts.isNotEmpty;
        _message = r.alerts.isEmpty
            ? 'Checked ${r.pushed} papers: your devices agree.'
            : r.alerts.map((a) => a.summary()).join('\n');
      });
    } catch (e) {
      setState(() {
        _bad = true;
        _message = 'Could not sync: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = SyncService.instance;
    if (!sync.isPaired) {
      return InfoBanner(
        tone: Tone.look,
        radius: 22,
        child: Text(
          'This device is not linked yet. Add a device to compare your copies.',
          style: AppText.body,
        ),
      );
    }
    return AppCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Relay address', style: AppText.bodyBold),
          const SizedBox(height: 4),
          TextField(
            controller: _url,
            decoration: const InputDecoration(hintText: 'https://...'),
          ),
          const SizedBox(height: 10),
          AppButton.primary(
            _busy ? 'Checking...' : 'Check my devices now',
            onPressed: _busy ? null : _sync,
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              style: AppText.body.copyWith(
                color: _bad ? AppColors.bad : AppColors.safe,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
