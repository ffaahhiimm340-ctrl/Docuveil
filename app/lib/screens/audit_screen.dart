import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/chips.dart';
import '../widgets/layout.dart';

/// How one detail compares across the owner's papers. Labels follow the
/// research plan: equivalent (fine), likely problem (worth a look), blocking.
enum Verdict { fine, look, fix }

extension VerdictX on Verdict {
  Tone get tone => switch (this) {
    Verdict.fine => Tone.ok,
    Verdict.look => Tone.look,
    Verdict.fix => Tone.bad,
  };
  String get label => switch (this) {
    Verdict.fine => 'Fine',
    Verdict.look => 'Worth a look',
    Verdict.fix => 'Needs fixing',
  };
}

class _Row {
  const _Row(this.detail, this.values, this.verdict, {this.oddIndex});
  final String detail;

  /// One value per paper in [_papers]; null means the paper does not show it.
  final List<String?> values;
  final Verdict verdict;
  final int? oddIndex;
}

const _papers = ['Aadhaar', 'PAN', 'Marksheet', 'Certificate'];
const _where = ['Phone', 'Laptop', 'Drive', 'Laptop'];

const _rows = [
  _Row(
    'Date of birth',
    ['04 Jul 2001', '04 Jul 2001', '14 Jul 2001', null],
    Verdict.fix,
    oddIndex: 2,
  ),
  _Row(
    'Surname',
    ['Verma', 'Verma', 'Verma', 'Varma'],
    Verdict.look,
    oddIndex: 3,
  ),
  _Row('First names', [
    'Asha R.',
    'Asha Rajesh',
    'Asha Rajesh',
    'Asha Rajesh',
  ], Verdict.fine),
  _Row("Father's name", [
    'Rajesh Verma',
    'R Verma',
    'Rajesh Verma',
    null,
  ], Verdict.fine),
];

/// 12 Check before applying: do all my papers agree for this purpose?
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  static const _purposes = ['PAN and Aadhaar link', 'Passport', 'Exam form'];
  String _purpose = _purposes.first;

  int _count(Verdict v) => _rows.where((r) => r.verdict == v).length;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);

    final purposes = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (wide) Text('I am applying for:', style: AppText.t3),
        for (final p in _purposes)
          OptionPill(
            p,
            selected: p == _purpose,
            onTap: () => setState(() => _purpose = p),
          ),
      ],
    );

    final counts = Row(
      children: [
        for (final v in Verdict.values.reversed) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: v.tone.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    '${_count(v)}',
                    style: AppText.num(24).copyWith(color: v.tone.fg),
                  ),
                  Text(
                    v.label,
                    textAlign: TextAlign.center,
                    style: AppText.smallBold.copyWith(
                      color: v.tone.fg,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (v != Verdict.fine) const SizedBox(width: 8),
        ],
      ],
    );

    final fix = _rows.firstWhere((r) => r.verdict == Verdict.fix);

    final cards = <Widget>[
      for (final r in _rows.where((r) => r.verdict != Verdict.fine))
        AppCard(
          borderColor: r.verdict == Verdict.fix
              ? AppColors.bad
              : AppColors.warnBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.detail, style: AppText.t2)),
                  StatusChip(r.verdict.label, tone: r.verdict.tone),
                ],
              ),
              const SizedBox(height: 8),
              if (r.verdict == Verdict.fix) ...[
                Row(
                  children: [
                    Expanded(
                      child: _Value(
                        '${_papers[0]} · ${_where[0]}',
                        r.values[0] ?? '',
                        Tone.gray,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Value(
                        '${_papers[r.oddIndex!]} · ${_where[r.oddIndex!]}',
                        r.values[r.oddIndex!] ?? '',
                        Tone.bad,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: AppText.body,
                    children: [
                      TextSpan(text: 'Fix: ', style: AppText.bodyBold),
                      const TextSpan(
                        text: 'ask your university to correct the marksheet. This link needs the date to match exactly.',
                      ),
                    ],
                  ),
                ),
              ] else
                Text.rich(
                  TextSpan(
                    style: AppText.body,
                    children: [
                      TextSpan(text: 'Aadhaar says '),
                      TextSpan(text: r.values[0], style: AppText.bodyBold),
                      TextSpan(text: '. Degree certificate (Laptop) says '),
                      TextSpan(text: r.values[3], style: AppText.bodyBold),
                      const TextSpan(text: '. Probably a typing slip.'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      InfoBanner(
        tone: Tone.ok,
        child: Text.rich(
          TextSpan(
            style: AppText.body,
            children: [
              TextSpan(text: 'Name is fine. ', style: AppText.bodyBold),
              const TextSpan(
                text: '"Asha R. Verma" and "Asha Rajesh Verma" match.',
              ),
            ],
          ),
        ),
      ),
    ];

    final steps = _Steps(fix: fix);

    return PageScaffold(
      title: 'Check before applying',
      subtitle: wide
          ? 'We compare your papers with each other so a small mismatch does not stop your application.'
          : null,
      back: false,
      bigTitle: true,
      maxWidth: wide ? 1180 : 640,
      bottom: wide
          ? null
          : [
              AppButton.primary(
                'Show me the fix steps',
                onPressed: () => context.go('/audit/fix'),
              ),
            ],
      children: [
        purposes,
        if (wide)
          TwoCol(
            sideWidth: 380,
            main: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final v in Verdict.values.reversed)
                    StatusChip(
                      '${_count(v)} ${v.label.toLowerCase()}',
                      tone: v.tone,
                    ),
                ],
              ),
              _Table(),
              Text(
                '"R" and "Rajesh" count as the same name, so they are marked Fine. A different date of birth never counts as the same, so it is marked Needs fixing.',
                style: AppText.sub,
              ),
            ],
            side: [steps],
          )
        else ...[
          counts,
          ...cards,
        ],
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value, this.tone);
  final String label;
  final String value;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tone == Tone.bad ? AppColors.badTint : AppColors.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.small.copyWith(
              color: tone == Tone.bad ? AppColors.bad : AppColors.ink2,
              fontSize: 14,
            ),
          ),
          Text(value, style: AppText.t3),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget head(String t, String w) => Expanded(
      flex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: AppText.smallBold),
          Text(w, style: AppText.small.copyWith(fontSize: 13)),
        ],
      ),
    );
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Detail', style: AppText.smallBold),
                ),
                for (var i = 0; i < _papers.length; i++)
                  head(_papers[i], _where[i]),
                Expanded(
                  flex: 2,
                  child: Text('Result', style: AppText.smallBold),
                ),
              ],
            ),
          ),
          for (final r in _rows) ...[
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(r.detail, style: AppText.t3)),
                  for (var i = 0; i < _papers.length; i++)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: i == r.oddIndex
                            ? const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              )
                            : EdgeInsets.zero,
                        decoration: i == r.oddIndex
                            ? BoxDecoration(
                                color: r.verdict.tone.bg,
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: Text(
                          r.values[i] ?? 'Not shown',
                          style: AppText.body.copyWith(
                            color: i == r.oddIndex
                                ? r.verdict.tone.fg
                                : (r.values[i] == null
                                      ? AppColors.ink2
                                      : AppColors.ink),
                            fontWeight: i == r.oddIndex
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusChip(
                        r.verdict.label,
                        tone: r.verdict.tone,
                        compact: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.fix});
  final _Row fix;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fix these, in this order', style: AppText.t2),
          const SizedBox(height: 14),
          const FixStep(
            1,
            Tone.bad,
            'Correct the date of birth on your marksheet',
            'Ask your university exam office. The link needs the date to match exactly.',
          ),
          const FixStep(
            2,
            Tone.look,
            'Check the spelling on your degree certificate',
            'It says "Varma". It can wait.',
          ),
          const FixStep(
            3,
            Tone.ok,
            'Then link your PAN and Aadhaar',
            'We will remind you once the marksheet is fixed.',
          ),
          const SizedBox(height: 4),
          AppButton.primary(
            'Save these steps as a checklist',
            onPressed: () => context.go('/audit/fix'),
          ),
        ],
      ),
    );
  }
}

/// One numbered step in a fix list.
class FixStep extends StatelessWidget {
  const FixStep(
    this.n,
    this.tone,
    this.title,
    this.text, {
    super.key,
    this.chips = const [],
  });

  final int n;
  final Tone tone;
  final String title;
  final String text;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$n', style: AppText.t3.copyWith(color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.t3),
                const SizedBox(height: 2),
                Text(text, style: AppText.sub),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: chips),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 13 Fix steps: the same list as a checklist with a weekly reminder.
class FixStepsScreen extends StatefulWidget {
  const FixStepsScreen({super.key});

  @override
  State<FixStepsScreen> createState() => _FixStepsScreenState();
}

class _FixStepsScreenState extends State<FixStepsScreen> {
  bool _remind = true;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Fix these, in order',
      backTo: '/audit',
      bottom: [
        AppButton.primary(
          'Save this checklist',
          onPressed: () => context.go('/'),
        ),
        AppButton.secondary(
          'I fixed the marksheet: scan it again',
          onPressed: () => context.go('/add'),
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('PAN and Aadhaar link', style: AppText.t3),
                  ),
                  Text('0 of 3 done', style: AppText.smallBold),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: const LinearProgressIndicator(
                  value: 0.06,
                  minHeight: 10,
                  color: AppColors.brand,
                  backgroundColor: AppColors.line,
                ),
              ),
            ],
          ),
        ),
        const AppCard(
          child: FixStep(
            1,
            Tone.bad,
            'Correct the date of birth on your marksheet',
            'Ask your university exam office. Take your Aadhaar with you.',
            chips: [
              LocChip('Marksheet · Google Drive', tone: Tone.bad),
              LocChip('Aadhaar · Phone', tone: Tone.ok),
            ],
          ),
        ),
        const AppCard(
          child: FixStep(
            2,
            Tone.look,
            'Check the spelling on your degree certificate',
            'It says "Varma". This can wait, it will not stop the PAN link.',
            chips: [LocChip('Certificate · Laptop only', tone: Tone.look)],
          ),
        ),
        const AppCard(
          child: FixStep(
            3,
            Tone.ok,
            'Then link your PAN and Aadhaar',
            'We will remind you once the marksheet is fixed and re-scanned.',
          ),
        ),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Remind me weekly', style: AppText.t3),
                    Text('Until all 3 steps are done.', style: AppText.small),
                  ],
                ),
              ),
              Switch(
                value: _remind,
                onChanged: (v) => setState(() => _remind = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
