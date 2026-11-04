import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'audit_rows.dart';
import 'derived.dart';
import 'sample_data.dart';
import 'vault.dart';

/// The owner's reminder choices, kept in the encrypted vault.
class ReminderPrefs {
  ReminderPrefs._();

  static const _key = 'reminder_prefs';
  static bool days30 = true;
  static bool days7 = true;
  static bool days1 = false;
  static bool weeklyFixSteps = true;

  static Future<void> load() async {
    final m = await Vault.readMeta(_key);
    if (m is! Map) return;
    days30 = m['days30'] as bool? ?? days30;
    days7 = m['days7'] as bool? ?? days7;
    days1 = m['days1'] as bool? ?? days1;
    weeklyFixSteps = m['weekly'] as bool? ?? weeklyFixSteps;
  }

  static Future<void> save() => Vault.saveMeta(_key, {
    'days30': days30,
    'days7': days7,
    'days1': days1,
    'weekly': weeklyFixSteps,
  });

  static List<int> get daysBefore => [
    if (days30) 30,
    if (days7) 7,
    if (days1) 1,
  ];
}

class PlannedReminder {
  const PlannedReminder(this.id, this.at, this.title, this.body);

  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// Reminders worth scheduling, at 9 am local time and only in the future.
/// The text names the paper but no personal details, since it can appear on a
/// lock screen.
List<PlannedReminder> planReminders(
  List<(String title, DateTime date)> dates,
  List<int> daysBefore,
  DateTime now,
) {
  final out = <PlannedReminder>[];
  var id = 1;
  for (final (title, date) in dates) {
    for (final before in daysBefore) {
      final d = date.subtract(Duration(days: before));
      final at = DateTime(d.year, d.month, d.day, 9);
      if (!at.isAfter(now)) continue;
      out.add(
        PlannedReminder(
          id++,
          at,
          title,
          before == 1 ? 'Due tomorrow. Open Docuveil to see it.' : 'Due in $before days. Open Docuveil to see it.',
        ),
      );
    }
  }
  return out;
}

/// Fix steps still open on the owner's own papers. Sample papers do not count.
int fixStepsLeft(List<VaultDoc> vault, String purpose, Set<String> done) {
  final mine = [for (final v in vault) if (!v.isDemo) v];
  if (mine.length < 2) return 0;
  return buildAuditView(mine, purposeFor(purpose)).actionable
      .where((r) => !done.contains(stepKey(r)))
      .length;
}

/// Next Monday at 9 am, for the weekly fix-steps reminder.
DateTime nextWeekly(DateTime now) {
  var d = DateTime(now.year, now.month, now.day, 9);
  while (d.weekday != DateTime.monday || !d.isAfter(now)) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// Puts the plan into the operating system's notification schedule.
class Reminders {
  Reminders._();

  static const _weeklyId = 100000;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'docuveil_reminders',
      'Reminders',
      channelDescription: 'Renewal dates and fix steps',
    ),
    windows: WindowsNotificationDetails(),
  );

  static bool get supported =>
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.windows,
      }.contains(defaultTargetPlatform);

  static Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        windows: WindowsInitializationSettings(
          appName: 'Docuveil',
          appUserModelId: 'Docuveil.App',
          guid: '6f1c7a52-3f0e-4c7b-9a41-2d8e5b7c1a90',
        ),
      ),
    );
    _ready = true;
  }

  /// Ask for permission to notify (Android 13+ shows a prompt once).
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Replace everything scheduled with the current plan. Returns how many.
  ///
  /// [askPermission] is off only in automated tests, where nobody can answer.
  static Future<int> reschedule({bool askPermission = true}) async {
    if (!_ready) return 0;
    final left = fixStepsLeft(Vault.docs.value, selectedPurpose, doneSteps);
    await _plugin.cancelAll();
    final now = DateTime.now();
    final renewals = renewalsFrom(SampleData.ownerSources, now);
    final plan = planReminders(
      [
        for (final r in renewals)
          (r.$1.title, DateTime.now().add(Duration(days: r.$3))),
      ],
      ReminderPrefs.daysBefore,
      now,
    );
    if (plan.isEmpty && left == 0) return 0;
    if (askPermission) await requestPermission();
    for (final r in plan) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    var count = plan.length;
    if (ReminderPrefs.weeklyFixSteps && left > 0) {
      await _plugin.zonedSchedule(
        id: _weeklyId,
        title: 'Papers to fix',
        body: 'You have fix steps left. Open Docuveil to see them.',
        scheduledDate: tz.TZDateTime.from(nextWeekly(now), tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      count++;
    }
    return count;
  }

  /// Show one now, to prove notifications reach this device.
  static Future<void> showTest() =>
      _plugin.show(id: 99999, title: 'Docuveil', body: 'Reminders are working.', notificationDetails: _details);

  static Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;
}
