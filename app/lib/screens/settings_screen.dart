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
import '../widgets/shell.dart';

/// 21 Settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _fingerprint = true;
  bool _alerts = true;
  bool _wifiOnly = false;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);

    Widget sw(String title, bool v, ValueChanged<bool> on, {String? sub}) =>
        RowTile(
          title: title,
          subtitle: sub,
          trailing: Switch(value: v, onChanged: on),
        );

    Widget link(IconData icon, String title, String route, {String? sub}) =>
        RowTile(
          leading: IconTile(icon, size: 44),
          title: title,
          subtitle: sub,
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.ink2,
          ),
          onTap: () => context.go(route),
        );

    return PageScaffold(
      title: 'Settings',
      subtitle: wide ? 'Simple choices. Change them any time.' : null,
      back: false,
      bigTitle: true,
      maxWidth: 720,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Text size', style: AppText.t3),
              Text(
                'Makes everything in the app bigger or smaller.',
                style: AppText.small,
              ),
              const SizedBox(height: 10),
              const TextSizeChoice(),
            ],
          ),
        ),
        ListGroup(
          children: [
            sw(
              'Fingerprint unlock',
              _fingerprint,
              (v) => setState(() => _fingerprint = v),
            ),
            sw(
              'Alerts on this device',
              _alerts,
              (v) => setState(() => _alerts = v),
              sub: 'Changes, renewals, backups',
            ),
            sw(
              'Sync only on Wi-Fi',
              _wifiOnly,
              (v) => setState(() => _wifiOnly = v),
            ),
          ],
        ),
        ListGroup(
          children: [
            link(
              Icons.folder_outlined,
              'Watched places',
              '/settings/places',
              sub: '${SampleData.watchedPlaces.length} folders and accounts',
            ),
            link(
              Icons.devices_rounded,
              'Devices and sync',
              '/devices',
              sub: '${SampleData.devices.length} devices',
            ),
            link(
              Icons.shield_outlined,
              'Safety centre',
              '/safety',
              sub: '1 file held',
            ),
            link(Icons.event_outlined, 'Renewals and dates', '/renewals'),
            link(Icons.help_outline_rounded, 'Help and privacy', '/help'),
          ],
        ),
        AppButton.text(
          'Lock the vault now',
          danger: true,
          onPressed: () => context.go('/unlock'),
        ),
      ],
    );
  }
}

/// 22 Watched places: only these folders and accounts are looked at.
class WatchedPlacesScreen extends StatefulWidget {
  const WatchedPlacesScreen({super.key});

  @override
  State<WatchedPlacesScreen> createState() => _WatchedPlacesScreenState();
}

class _WatchedPlacesScreenState extends State<WatchedPlacesScreen> {
  late final List<bool> _on = [for (final p in SampleData.watchedPlaces) p.on];

  @override
  Widget build(BuildContext context) {
    Widget section(String title, PlaceKind kind) {
      final items = [
        for (var i = 0; i < SampleData.watchedPlaces.length; i++)
          if (SampleData.watchedPlaces[i].kind == kind) i,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: AppText.t2),
          ),
          ListGroup(
            children: [
              for (final i in items)
                RowTile(
                  leading: IconTile(
                    SampleData.watchedPlaces[i].kind == PlaceKind.cloud
                        ? Icons.cloud_outlined
                        : Icons.folder_outlined,
                    size: 44,
                  ),
                  title: SampleData.watchedPlaces[i].name,
                  path: SampleData.watchedPlaces[i].path,
                  trailing: Switch(
                    value: _on[i],
                    onChanged: (v) => setState(() => _on[i] = v),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return PageScaffold(
      title: 'Watched places',
      backTo: '/settings',
      bottom: [AppButton.primary('Add a place to watch', onPressed: () {})],
      children: [
        Text(
          'Docuveil only looks at the places you choose here. Nothing else is touched.',
          style: AppText.sub,
        ),
        section('On this phone', PlaceKind.phone),
        section("On Asha's laptop", PlaceKind.laptop),
        section('In the cloud', PlaceKind.cloud),
      ],
    );
  }
}

/// 23 Help and privacy.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = {
    'How do you know a paper changed?': 'When you add a paper we read its details (name, number, date) and save them as your original. Every copy is read the same way and compared, detail by detail.',
    'What is the ring on each paper?': 'Each piece of the ring is one detail on the paper. If one detail changes, only that piece turns red, so you can see exactly what changed.',
    'Is a re-scan counted as a change?': 'No. Saving again, scanning again or shrinking a file does not change what is written on it, so it is ignored as harmless.',
    'What if I lose my phone?': 'Your papers are also on your other devices and cloud. Remove the lost phone under Devices and sync and its access stops.',
    'Why only fake documents in tests?': 'Docuveil is a research project. All testing uses made-up documents so no real identity paper is ever used.',
  };

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Help and privacy',
      backTo: '/settings',
      children: [
        InfoBanner(
          tone: Tone.brand,
          icon: Icons.lock_outline_rounded,
          radius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your papers stay with you', style: AppText.t2),
              const SizedBox(height: 4),
              Text(
                'Papers are stored only on your own devices and your own cloud. Our server never sees them. It only passes along scrambled codes, so it cannot tell which paper an alert is about.',
                style: AppText.body,
              ),
            ],
          ),
        ),
        Text('Common questions', style: AppText.t2),
        ListGroup(
          children: [
            for (final e in _faq.entries)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedAlignment: Alignment.centerLeft,
                  title: Text(e.key, style: AppText.t3),
                  children: [Text(e.value, style: AppText.sub)],
                ),
              ),
          ],
        ),
        Center(
          child: Text(
            'Docuveil version 0.1 · research project',
            style: AppText.small,
          ),
        ),
        AppButton.secondary(
          'Delete everything from this device',
          danger: true,
          onPressed: () {},
        ),
      ],
    );
  }
}
