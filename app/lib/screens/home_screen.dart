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
import '../widgets/seal_ring.dart';

/// 04 Home: what needs attention, where papers live, and the papers themselves.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final papers = SampleData.papers;
    final changed = papers.where((p) => p.hasChange).toList();

    final attention = changed.isEmpty
        ? InfoBanner(
            tone: Tone.ok,
            radius: 24,
            child: Text(
              'All your papers match their originals.',
              style: AppText.body,
            ),
          )
        : _AttentionCard(paper: changed.first);

    final where = _WhereCard(papers: papers);

    final shown = wide ? papers.take(4).toList() : papers.take(2).toList();

    final paperList = wide
        ? Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final p in shown) SizedBox(width: 290, child: PaperCard(p)),
            ],
          )
        : Column(
            children: [
              for (final p in shown) ...[
                PaperRow(p),
                const SizedBox(height: 8),
              ],
            ],
          );

    final main = <Widget>[
      attention,
      if (wide) const _QuickActions(),
      where,
      SectionTitle(
        'Your papers',
        action: 'See all ${papers.length}',
        onAction: () => context.go('/papers'),
      ),
      paperList,
    ];

    final side = <Widget>[const _ComingUp()];

    return PageScaffold(
      title: 'Good morning, ${SampleData.userName}',
      subtitle: wide
          ? 'Your papers are being watched on 2 devices and 1 cloud account.'
          : 'Your papers are being watched.',
      back: false,
      bigTitle: true,
      maxWidth: wide ? 1180 : 640,
      trailing: wide
          ? null
          : IconButton.outlined(
              tooltip: 'Settings and text size',
              onPressed: () => context.go('/settings'),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: AppColors.card,
                side: const BorderSide(color: AppColors.line, width: 2),
              ),
              icon: Text('A', style: AppText.t3),
            ),
      children: [
        wide
            ? TwoCol(main: main, side: side, sideWidth: 330)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _gap(main),
              ),
      ],
    );
  }

  static List<Widget> _gap(List<Widget> items) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) const SizedBox(height: 14),
      items[i],
    ],
  ];
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.paper});
  final Paper paper;

  @override
  Widget build(BuildContext context) {
    final change = paper.fields.firstWhere(
      (f) => f.isChanged,
      orElse: () => paper.fields.first,
    );
    return AppCard(
      color: AppColors.badTint,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SealRing.forPaper(paper, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1 thing needs you',
                      style: AppText.t2.copyWith(color: AppColors.bad),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${paper.shortTitle} changed on Google Drive. ${change.label}: ${change.was} to ${change.value}.',
                      style: AppText.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppButton.primary(
            'See what changed',
            onPressed: () => context.go('/papers/${paper.id}/changed'),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, String route) => Expanded(
      child: AppCard(
        radius: 22,
        padding: const EdgeInsets.all(18),
        onTap: () => context.go(route),
        child: Row(
          children: [
            IconTile(icon, size: 52, circle: true),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: AppText.t3.copyWith(fontSize: 19)),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        tile(Icons.add_rounded, 'Add a paper', '/add'),
        const SizedBox(width: 14),
        tile(Icons.fact_check_outlined, 'Check a file', '/check-file'),
        const SizedBox(width: 14),
        tile(Icons.verified_user_outlined, 'Check before applying', '/audit'),
      ],
    );
  }
}

class _WhereCard extends StatelessWidget {
  const _WhereCard({required this.papers});
  final List<Paper> papers;

  int _count(PlaceKind k) =>
      papers.where((p) => p.copies.any((c) => c.kind == k)).length;

  @override
  Widget build(BuildContext context) {
    final single = papers.where((p) => p.copies.length == 1).toList();
    final driveChanged = papers.any(
      (p) => p.copies.any(
        (c) => c.kind == PlaceKind.cloud && c.state == CopyState.changed,
      ),
    );

    Widget place(PlaceKind k, String name, {Tone tone = Tone.brand}) =>
        Expanded(
          child: Material(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.go('/locations'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 6,
                ),
                child: Column(
                  children: [
                    Icon(k.icon, color: tone.fg, size: 26),
                    Text('${_count(k)}', style: AppText.num(20)),
                    Text(name, style: AppText.smallBold),
                  ],
                ),
              ),
            ),
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Where your papers are',
            action: 'See all',
            onAction: () => context.go('/locations'),
          ),
          Row(
            children: [
              place(PlaceKind.phone, 'Phone'),
              const SizedBox(width: 8),
              place(PlaceKind.laptop, 'Laptop'),
              const SizedBox(width: 8),
              place(
                PlaceKind.cloud,
                'Drive',
                tone: driveChanged ? Tone.bad : Tone.brand,
              ),
            ],
          ),
          if (single.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: AppText.small,
                children: [
                  TextSpan(text: '${single.length} paper has only one copy: '),
                  TextSpan(
                    text: single.first.shortTitle,
                    style: AppText.smallBold.copyWith(color: AppColors.ink),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComingUp extends StatelessWidget {
  const _ComingUp();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Coming up', style: AppText.t2),
          const SizedBox(height: 12),
          for (final d in SampleData.dates.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: d.tone.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          d.month,
                          style: AppText.smallBold.copyWith(
                            color: d.tone.fg,
                            fontSize: 14,
                          ),
                        ),
                        Text(d.day, style: AppText.num(20)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title, style: AppText.t3),
                        Text(d.when, style: AppText.small),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: AppColors.line),
          const SizedBox(height: 4),
          Text(
            'Tip: your degree certificate has only one copy. Add a backup so a loss is not a problem.',
            style: AppText.sub,
          ),
        ],
      ),
    );
  }
}
