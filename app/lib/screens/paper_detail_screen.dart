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

/// 06 Paper detail: details read from the paper, and where every copy lives.
class PaperDetailScreen extends StatelessWidget {
  const PaperDetailScreen({super.key, required this.paperId});
  final String paperId;

  @override
  Widget build(BuildContext context) {
    final paper = SampleData.paperById(paperId);
    final wide = Breakpoints.isWide(context);

    final header = Row(
      children: [
        SealRing.forPaper(paper, size: wide ? 110 : 76),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusChip(
                paper.hasChange ? 'Changed: 1 detail' : paper.statusText,
                tone: paper.status.tone,
              ),
              const SizedBox(height: 6),
              Text(
                'Original saved 12 Aug. Last checked today, 9:13 am.',
                style: AppText.small,
              ),
            ],
          ),
        ),
      ],
    );

    final fields = AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details we read from this paper', style: AppText.smallBold),
          const SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              for (final f in paper.fields)
                SizedBox(
                  width: wide ? 220 : 150,
                  child: Container(
                    padding: f.isChanged
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                        : EdgeInsets.zero,
                    decoration: f.isChanged
                        ? BoxDecoration(
                            color: AppColors.badTint,
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.label,
                          style: f.isChanged
                              ? AppText.smallBold.copyWith(color: AppColors.bad)
                              : AppText.small,
                        ),
                        Text(
                          f.isChanged ? '${f.value} (was ${f.was})' : f.value,
                          style: AppText.t3.copyWith(
                            color: f.isChanged ? AppColors.bad : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final where = AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Where it lives',
            action: 'All places',
            onAction: () => context.go('/locations'),
          ),
          CopyLines(paper.copies),
          if (paper.copies.length == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoBanner(
                tone: Tone.look,
                child: Text(
                  'Only one copy exists. Add a backup on another device or in the cloud.',
                  style: AppText.body,
                ),
              ),
            ),
        ],
      ),
    );

    final history = AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('History', style: AppText.t2),
          const SizedBox(height: 8),
          if (paper.hasChange)
            const _HistoryLine(
              Tone.bad,
              'Google Drive copy edited',
              'Today, 9:12 am · CGPA 8.74 to 9.40',
            ),
          if (paper.hasChange)
            const _HistoryLine(
              Tone.ok,
              'Checked on laptop and phone: no change',
              'Today, 9:13 am',
            ),
          const _HistoryLine(Tone.ok, 'Saved as original', '12 Aug, 6:40 pm'),
        ],
      ),
    );

    final actions = <Widget>[
      if (paper.hasChange)
        AppButton.primary(
          'See what changed',
          onPressed: () => context.go('/papers/${paper.id}/changed'),
        ),
      AppButton.secondary(
        'Check another copy of this paper',
        onPressed: () => context.go('/check-file'),
      ),
    ];

    final main = <Widget>[header, fields, if (wide) history];
    final side = <Widget>[where, ...actions];

    return PageScaffold(
      title: paper.title,
      backTo: '/papers',
      maxWidth: wide ? 1180 : 640,
      children: [
        if (wide)
          TwoCol(main: main, side: side, sideWidth: 420)
        else ...[
          header,
          fields,
          where,
          ...actions,
        ],
      ],
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine(this.tone, this.title, this.when);
  final Tone tone;
  final String title;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.t3),
                Text(when, style: AppText.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
