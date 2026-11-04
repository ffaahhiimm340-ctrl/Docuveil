import 'package:flutter/material.dart';

import '../data/reminders.dart';
import '../data/sample_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/buttons.dart';
import '../widgets/cards.dart';
import '../widgets/layout.dart';

/// 19 Renewals and dates, with reminders before each date.
class RenewalsScreen extends StatefulWidget {
  const RenewalsScreen({super.key});

  @override
  State<RenewalsScreen> createState() => _RenewalsScreenState();
}

class _RenewalsScreenState extends State<RenewalsScreen> {
  void _set(void Function() change) {
    setState(change);
    ReminderPrefs.save();
    Reminders.reschedule();
  }

  @override
  Widget build(BuildContext context) {
    Widget toggle(String label, bool v, ValueChanged<bool> on) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.t3.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
          Switch(value: v, onChanged: on),
        ],
      ),
    );

    return PageScaffold(
      title: 'Renewals and dates',
      backTo: '/',
      bottom: [AppButton.primary('Add my own date', onPressed: () {})],
      children: [
        for (final (i, d) in SampleData.dates.indexed)
          AppCard(
            borderColor: i == 0
                ? AppColors.warnBorder
                : null,
            child: Row(
              children: [
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: d.tone.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        d.month,
                        style: AppText.smallBold.copyWith(color: d.tone.fg),
                      ),
                      Text(d.day, style: AppText.num(24)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title, style: AppText.t3),
                      Text(
                        d.when,
                        style: AppText.smallBold.copyWith(color: d.tone.fg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remind me before', style: AppText.t3),
              toggle('30 days', ReminderPrefs.days30, (v) => _set(() => ReminderPrefs.days30 = v)),
              toggle('7 days', ReminderPrefs.days7, (v) => _set(() => ReminderPrefs.days7 = v)),
              toggle('1 day', ReminderPrefs.days1, (v) => _set(() => ReminderPrefs.days1 = v)),
            ],
          ),
        ),
      ],
    );
  }
}
