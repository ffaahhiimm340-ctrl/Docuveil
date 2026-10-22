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

/// 14 Alerts: sorted by urgency, with the place a problem was found.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final all = SampleData.alerts;
    final shown = switch (_filter) {
      'urgent' => all.where((a) => a.group == 'urgent').toList(),
      'soon' => all.where((a) => a.group == 'soon').toList(),
      _ => all,
    };
    final wide = Breakpoints.isWide(context);

    Widget group(String key, String label, Color color) {
      final items = shown.where((a) => a.group == key).toList();
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Text(label, style: AppText.smallBold.copyWith(color: color)),
          ),
          for (final a in items) ...[_AlertCard(a), const SizedBox(height: 8)],
        ],
      );
    }

    return PageScaffold(
      title: 'Alerts',
      back: false,
      bigTitle: true,
      maxWidth: wide ? 760 : 640,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OptionPill(
              'All ${all.length}',
              selected: _filter == 'all',
              onTap: () => setState(() => _filter = 'all'),
            ),
            OptionPill(
              'Urgent 1',
              selected: _filter == 'urgent',
              onTap: () => setState(() => _filter = 'urgent'),
            ),
            OptionPill(
              'Reminders 2',
              selected: _filter == 'soon',
              onTap: () => setState(() => _filter = 'soon'),
            ),
          ],
        ),
        group('urgent', 'URGENT: ACT TODAY', AppColors.bad),
        group('soon', 'COMING UP', AppColors.warn),
        group('info', 'FOR YOUR INFORMATION', AppColors.ink2),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard(this.alert);
  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    final paper = alert.paperId == null
        ? null
        : SampleData.paperById(alert.paperId!);
    return AppCard(
      borderColor: alert.group == 'urgent' ? AppColors.bad : null,
      onTap: () {
        if (alert.group == 'urgent' && paper != null) {
          context.go('/papers/${paper.id}/changed');
        } else if (paper != null) {
          context.go('/papers/${paper.id}');
        } else {
          context.go('/devices');
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(alert.tone.icon, tone: alert.tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: AppText.t3),
                Text(alert.text, style: AppText.sub),
                if (alert.group == 'urgent' && paper != null) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final c in paper.copies) LocChip.forCopy(c),
                      if (alert.when != null)
                        Text(alert.when!, style: AppText.small),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
