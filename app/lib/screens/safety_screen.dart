import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/safety_center.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
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
  String? _guardError;

  Future<void> _toggleGuard(bool on) async {
    setState(() => _guardError = null);
    try {
      if (on) {
        await DecoyGuard.enable(await getApplicationDocumentsDirectory());
      } else {
        await DecoyGuard.disable();
      }
    } catch (e) {
      setState(() => _guardError = 'Could not change the guard: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SafetyLog.reports,
      builder: (context, reports, _) {
        final scripts = reports.where((r) => r.scripts.isNotEmpty).toList();
        final exposed = reports.where((r) => r.shared && r.sensitive.isNotEmpty).toList();
        return PageScaffold(
          title: 'Safety centre',
          backTo: '/settings',
          children: [
            AppCard(
              borderColor: scripts.isEmpty ? null : AppColors.warnBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconTile(
                        Icons.shield_outlined,
                        tone: scripts.isEmpty ? Tone.ok : Tone.look,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hidden-script scan', style: AppText.t3),
                            Text(
                              'Checked ${reports.length} file${reports.length == 1 ? '' : 's'} added since opening the app',
                              style: AppText.small,
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        scripts.isEmpty ? 'Nothing found' : '${scripts.length} found',
                        tone: scripts.isEmpty ? Tone.ok : Tone.look,
                        compact: true,
                      ),
                    ],
                  ),
                  for (final r in scripts) ...[
                    const SizedBox(height: 10),
                    _FileBox(r.fileName, r.path, r.scripts.map((s) => s.what).join(' ')),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Looks for macros and scripts in documents. It is not an antivirus, and a clean result does not prove a file is safe.',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            AppCard(
              borderColor: DecoyGuard.alarm.value == null ? null : AppColors.bad,
              child: ValueListenableBuilder(
                valueListenable: DecoyGuard.alarm,
                builder: (context, alarm, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconTile(
                          Icons.laptop_rounded,
                          tone: alarm == null ? Tone.ok : Tone.bad,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ransomware guard', style: AppText.t3),
                              Text('Windows only', style: AppText.small),
                            ],
                          ),
                        ),
                        Switch(
                          value: DecoyGuard.active.value,
                          onChanged: DecoyGuard.supported ? _toggleGuard : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      !DecoyGuard.supported
                          ? 'Not available on this device.'
                          : DecoyGuard.active.value
                          ? 'Watching 3 decoy files while the app is open. It warns you; it cannot stop an attack.'
                          : 'Off. Turning it on puts 3 small decoy files in a hidden folder in your Documents, and turning it off removes them.',
                      style: AppText.sub,
                    ),
                    if (_guardError != null)
                      Text(
                        _guardError!,
                        style: AppText.smallBold.copyWith(color: AppColors.bad),
                      ),
                    if (alarm != null) ...[
                      const SizedBox(height: 8),
                      StatusChip(alarm, tone: Tone.bad),
                    ] else if (DecoyGuard.active.value) ...[
                      const SizedBox(height: 8),
                      const StatusChip('No problems found', tone: Tone.ok),
                    ],
                  ],
                ),
              ),
            ),
            AppCard(
              borderColor: exposed.isEmpty ? null : AppColors.warnBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconTile(
                        Icons.info_outline_rounded,
                        tone: exposed.isEmpty ? Tone.ok : Tone.look,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ID numbers in shared places',
                          style: AppText.t3,
                        ),
                      ),
                      StatusChip(
                        exposed.isEmpty ? 'None found' : '${exposed.length} to review',
                        tone: exposed.isEmpty ? Tone.ok : Tone.look,
                        compact: true,
                      ),
                    ],
                  ),
                  for (final r in exposed) ...[
                    const SizedBox(height: 10),
                    _FileBox(
                      r.fileName,
                      r.path,
                      'Has ${r.sensitive.map((s) => '${s.kind} ${s.masked}').join(', ')}, and is in a folder other people may be able to open.',
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Checks files as you add them. The folder check goes by its name, so it can be wrong.',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FileBox extends StatelessWidget {
  const _FileBox(this.name, this.path, this.note);

  final String name;
  final String? path;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppText.bodyBold),
          if (path != null) PathText(path!),
          Text(note, style: AppText.small),
        ],
      ),
    );
  }
}
