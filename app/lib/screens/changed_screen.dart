import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/sample_data.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/layout.dart';
import '../widgets/seal_ring.dart';

/// 10 Something changed: the field that changed, old and new value, a plain
/// verdict, and every copy so the owner knows which one is the original.
class ChangedScreen extends StatelessWidget {
  const ChangedScreen({super.key, required this.paperId});
  final String paperId;

  @override
  Widget build(BuildContext context) {
    final paper = SampleData.paperById(paperId);
    final change = paper.fields.firstWhere(
      (f) => f.isChanged,
      orElse: () => paper.fields.first,
    );
    final original = paper.copies.firstWhere(
      (c) => c.state == CopyState.original,
      orElse: () => paper.copies.first,
    );
    final changedCopy = paper.copies.firstWhere(
      (c) => c.state == CopyState.changed,
      orElse: () => paper.copies.last,
    );
    final wide = Breakpoints.isWide(context);

    final top = Row(
      children: [
        SealRing.forPaper(paper, size: wide ? 120 : 72),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your ${change.label.replaceAll(', ', ' ')} was changed',
                style: wide
                    ? AppText.t0Wide
                    : AppText.t2.copyWith(height: 1.25),
              ),
              const SizedBox(height: 4),
              Text(
                '${paper.title} · found on ${changedCopy.placeName} today, 9:12 am',
                style: AppText.small,
              ),
            ],
          ),
        ),
      ],
    );

    Widget valueCard(
      String head,
      String place,
      String value,
      Tone tone,
      String path,
    ) => Expanded(
      child: AppCard(
        borderColor: tone.fg,
        padding: EdgeInsets.all(wide ? 22 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              head,
              style: AppText.smallBold.copyWith(color: tone.fg, fontSize: 16),
            ),
            Text(place, style: AppText.small),
            if (wide) PathText(path),
            const SizedBox(height: 4),
            Text(value, style: AppText.num(wide ? 52 : 34)),
          ],
        ),
      ),
    );

    final compare = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        valueCard(
          'Your original',
          original.placeName,
          change.was ?? '',
          Tone.ok,
          original.path,
        ),
        const SizedBox(width: 10),
        valueCard(
          'Changed copy',
          changedCopy.placeName,
          change.value,
          Tone.bad,
          changedCopy.path,
        ),
      ],
    );

    // The engine's verdict for the most serious changed copy.
    final v = paper.verdict;
    final verdict = InfoBanner(
      tone: v == null || v.tamper ? Tone.bad : Tone.look,
      icon: Icons.warning_amber_rounded,
      child: Text.rich(
        TextSpan(
          style: AppText.body,
          children: [
            TextSpan(
              text: '${v?.title ?? 'No change found.'} ',
              style: AppText.bodyBold,
            ),
            TextSpan(text: v?.text ?? ''),
          ],
        ),
      ),
    );

    final fine = InfoBanner(
      tone: Tone.ok,
      child: Text(
        'The other ${paper.matchingDetails} details still match.',
        style: AppText.body,
      ),
    );

    final copies = AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(wide ? 'Every copy' : 'Where it lives', style: AppText.t2),
          CopyLines(paper.copies, compact: !wide),
        ],
      ),
    );

    final actions = <Widget>[
      AppButton.primary(
        'Restore my original to ${changedCopy.placeName}',
        onPressed: () => _restore(context, changedCopy.placeName),
      ),
      Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              'I changed it',
              onPressed: () => _ack(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton.secondary(
              'Remind me later',
              onPressed: () => context.go('/'),
            ),
          ),
        ],
      ),
    ];

    if (wide) {
      return PageScaffold(
        title: 'Something changed',
        backTo: '/',
        maxWidth: 1180,
        children: [
          TwoCol(
            main: [top, compare, verdict, fine],
            side: [
              AppCard(
                radius: 24,
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('What would you like to do?', style: AppText.t2),
                    const SizedBox(height: 12),
                    ...actions.expand((w) => [w, const SizedBox(height: 10)]),
                  ],
                ),
              ),
              copies,
            ],
            sideWidth: 420,
          ),
        ],
      );
    }

    return PageScaffold(
      title: 'Something changed',
      backTo: '/',
      bottom: actions,
      children: [top, compare, verdict, fine, copies],
    );
  }

  void _restore(BuildContext context, String place) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restoring your original to $place… (demo)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _ack(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Marked as your own change. Your original will be updated. (demo)',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
