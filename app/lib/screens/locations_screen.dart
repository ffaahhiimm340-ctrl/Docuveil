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

/// 15 Where my papers are: every copy of every paper, grouped by place or by paper.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  bool _byPlace = true;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final papers = SampleData.papers;
    final single = papers.where((p) => p.copies.length == 1).toList();

    final body = _byPlace
        ? _ByPlace(papers: papers, wide: wide)
        : Column(
            children: [
              for (final p in papers) ...[
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
                  borderColor: p.hasChange ? AppColors.bad : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(p.title, style: AppText.t2)),
                          StatusChip(
                            p.statusText,
                            tone: p.status.tone,
                            compact: true,
                          ),
                        ],
                      ),
                      CopyLines(p.copies, compact: true),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );

    return PageScaffold(
      title: 'Where my papers are',
      subtitle: wide
          ? 'Every copy of every paper, with its exact location.'
          : null,
      backTo: '/',
      maxWidth: wide ? 1180 : 640,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OptionPill(
              'By place',
              selected: _byPlace,
              onTap: () => setState(() => _byPlace = true),
            ),
            OptionPill(
              'By paper',
              selected: !_byPlace,
              onTap: () => setState(() => _byPlace = false),
            ),
          ],
        ),
        if (single.isNotEmpty)
          InfoBanner(
            tone: Tone.look,
            child: Text.rich(
              TextSpan(
                style: AppText.body,
                children: [
                  TextSpan(
                    text: single.first.shortTitle,
                    style: AppText.bodyBold,
                  ),
                  const TextSpan(
                    text: ' is only on your laptop. If that laptop is lost, so is the paper. ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => context.go('/add'),
                      child: Text(
                        'Add a backup',
                        style: AppText.bodyBold.copyWith(
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        body,
      ],
    );
  }
}

class _ByPlace extends StatelessWidget {
  const _ByPlace({required this.papers, required this.wide});
  final List<Paper> papers;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    Widget card(
      PlaceKind kind,
      String name,
      String detail,
      String status,
      Tone tone,
    ) {
      final entries = <(Paper, PaperCopy)>[];
      for (final p in papers) {
        for (final c in p.copies) {
          if (c.kind == kind) entries.add((p, c));
        }
      }
      return AppCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        borderColor: tone == Tone.bad ? AppColors.bad : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  kind.icon,
                  tone: tone == Tone.bad ? Tone.bad : Tone.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppText.t3.copyWith(fontSize: 20)),
                      Text(
                        '$detail · ${entries.length} papers',
                        style: AppText.small,
                      ),
                    ],
                  ),
                ),
                StatusChip(status, tone: tone, compact: true),
              ],
            ),
            const SizedBox(height: 6),
            for (final e in entries) ...[
              const Divider(height: 1, color: AppColors.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: InkWell(
                  onTap: () => context.go('/papers/${e.$1.id}'),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.$1.shortTitle, style: AppText.bodyBold),
                            PathText(e.$2.path),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        e.$2.state == CopyState.original &&
                                e.$1.copies.length == 1
                            ? 'Only copy'
                            : e.$2.state.label,
                        tone: e.$1.copies.length == 1
                            ? Tone.look
                            : e.$2.state.tone,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final cards = [
      card(PlaceKind.phone, "Asha's phone", 'Android', 'Online', Tone.ok),
      card(
        PlaceKind.laptop,
        "Asha's laptop",
        'Windows · synced 2 min ago',
        'Online',
        Tone.ok,
      ),
      card(
        PlaceKind.cloud,
        'Google Drive',
        'asha.verma@example.com',
        '1 changed',
        Tone.bad,
      ),
    ];

    if (!wide) {
      return Column(
        children: [
          for (final c in cards) ...[c, const SizedBox(height: 10)],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}
