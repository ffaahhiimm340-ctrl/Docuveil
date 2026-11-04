import 'package:docuveil_engine/docuveil_engine.dart'
    show DivergenceAlert, ExtractedDoc, Urgency, normalizeDate;

import '../models/models.dart';
import '../theme/app_colors.dart';
import 'audit_rows.dart' show docTitle;
import 'copy_check.dart';
import 'vault.dart';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// Dates at or under this many days away also appear as alerts.
const reminderWindowDays = 180;

/// The date a paper must be renewed by, if it has one.
DateTime? renewalDateOf(ExtractedDoc doc) {
  for (final key in const ['expiry_date', 'renewal_date']) {
    final v = doc.fields[key];
    if (v == null) continue;
    // normalizeDate gives yyyy-mm-dd for every format it understands.
    final parsed = DateTime.tryParse(normalizeDate(v));
    if (parsed != null) return parsed;
  }
  return null;
}

String _when(int days) {
  if (days < 0) return days == -1 ? 'Expired yesterday' : 'Expired ${-days} days ago';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 60) return 'In $days days';
  return 'In ${(days / 30.44).round()} months';
}

Tone _toneFor(int days) => days <= 30
    ? Tone.bad
    : days <= reminderWindowDays
    ? Tone.look
    : Tone.brand;

/// Every renewal date among [sources], soonest first.
List<(DateItem, PaperSource, int)> renewalsFrom(
  List<PaperSource> sources,
  DateTime today,
) {
  final out = <(DateItem, PaperSource, int)>[];
  final day = DateTime(today.year, today.month, today.day);
  for (final s in sources) {
    final original = s.copies.firstWhere(
      (c) => c.original,
      orElse: () => s.copies.first,
    );
    final date = renewalDateOf(original.doc);
    if (date == null) continue;
    final days = date.difference(day).inDays;
    out.add((
      DateItem(
        month: _months[date.month - 1],
        day: date.day.toString().padLeft(2, '0'),
        title: '${s.title} renews',
        when: _when(days),
        tone: _toneFor(days),
      ),
      s,
      days,
    ));
  }
  out.sort((a, b) => a.$3.compareTo(b.$3));
  return out;
}

/// Alerts worked out from the papers themselves.
List<AlertItem> alertsFrom(
  List<Paper> papers,
  List<(DateItem, PaperSource, int)> renewals,
) {
  final urgent = <AlertItem>[], soon = <AlertItem>[];
  for (final p in papers) {
    final bad = p.copies.where((c) => c.state != CopyState.original);
    final flagged = bad.where(
      (c) => c.state == CopyState.changed || c.state == CopyState.review,
    );
    if (p.status == PaperStatus.changed) {
      final copy = flagged.firstWhere((c) => c.state == CopyState.changed);
      final original = p.copies.firstWhere(
        (c) => c.state == CopyState.original,
        orElse: () => p.copies.first,
      );
      final what = p.fields
          .where((f) => f.isChanged)
          .map((f) => '${f.label} went from ${f.was} to ${f.value}')
          .join('; ');
      urgent.add(
        AlertItem(
          group: 'urgent',
          tone: Tone.bad,
          title: '${p.shortTitle} changed on ${copy.placeName}',
          text: '$what. Your copy on ${original.placeName} is the original.',
          paperId: p.id,
        ),
      );
    } else if (flagged.isNotEmpty) {
      soon.add(
        AlertItem(
          group: 'soon',
          tone: Tone.look,
          title: '${p.shortTitle} reads differently on ${flagged.first.placeName}',
          text: p.verdict?.text ?? 'Please compare it with your original.',
          paperId: p.id,
        ),
      );
    }
    if (p.copies.length == 1) {
      soon.add(
        AlertItem(
          group: 'soon',
          tone: Tone.look,
          title: '${p.shortTitle} has only one copy',
          text: 'It is only on ${p.copies.single.placeName}. Add a backup.',
          paperId: p.id,
        ),
      );
    }
  }
  for (final (d, s, days) in renewals) {
    if (days > reminderWindowDays) continue;
    soon.add(
      AlertItem(
        group: days < 0 ? 'urgent' : 'soon',
        tone: d.tone,
        title: d.title,
        text: '${d.when}: ${d.day} ${d.month}.',
        paperId: s.id,
      ),
    );
  }
  return [...urgent, ...soon];
}

/// Alerts for copies on the owner's other devices that disagree with this
/// one. They cannot say which copy is right, so they lead to the Devices page.
List<AlertItem> syncAlerts(List<DivergenceAlert> found) => [
  for (final a in found)
    AlertItem(
      group: switch (a.urgency) {
        Urgency.immediate => 'urgent',
        Urgency.batched => 'soon',
        Urgency.low => 'info',
      },
      tone: a.urgency == Urgency.immediate ? Tone.bad : Tone.look,
      title: 'A copy differs on another device',
      text: a.summary(),
    ),
];

/// A paper the owner added through the Add flow, as a one-copy source.
PaperSource sourceFromVault(VaultDoc v) {
  final date = renewalDateOf(v.doc);
  return PaperSource(
    id: v.doc.id,
    title: docTitle(v.doc.type),
    shortTitle: docTitle(v.doc.type),
    statusText: date == null
        ? 'Saved as your original'
        : 'Renews ${date.day} ${_titleMonth(date.month)}',
    copies: [
      CopySnapshot(
        kind: PlaceKind.laptop,
        placeName: v.location,
        path: v.fileName ?? v.doc.id,
        sha256: v.doc.id,
        doc: v.doc,
        original: true,
      ),
    ],
  );
}

String _titleMonth(int m) {
  final s = _months[m - 1];
  return s[0] + s.substring(1).toLowerCase();
}
