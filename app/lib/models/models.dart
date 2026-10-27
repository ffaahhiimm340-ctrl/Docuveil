import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// NOTE: rebuilt from how the screens use these types, because the original
// models.dart was never committed (see PR #3). If the original turns up, prefer
// it and keep this file's names in sync.

/// Where a copy of a paper lives.
enum PlaceKind { phone, laptop, cloud }

extension PlaceKindX on PlaceKind {
  IconData get icon => switch (this) {
    PlaceKind.phone => Icons.smartphone_rounded,
    PlaceKind.laptop => Icons.laptop_rounded,
    PlaceKind.cloud => Icons.cloud_outlined,
  };
}

/// How one copy compares with the owner's saved original. [review] means a
/// detail reads differently in a way a re-scan could explain.
enum CopyState { original, same, review, changed }

extension CopyStateX on CopyState {
  String get label => switch (this) {
    CopyState.original => 'Original',
    CopyState.same => 'Same',
    CopyState.review => 'Check',
    CopyState.changed => 'Changed',
  };

  Tone get tone => switch (this) {
    CopyState.original || CopyState.same => Tone.ok,
    CopyState.review => Tone.look,
    CopyState.changed => Tone.bad,
  };
}

/// What the engine concluded about the most serious changed copy.
class PaperVerdict {
  const PaperVerdict(this.title, this.text, {this.tamper = true});

  final String title;
  final String text;
  final bool tamper;
}

/// Overall state of a paper's seal.
enum PaperStatus { safe, look, changed }

extension PaperStatusX on PaperStatus {
  Tone get tone => switch (this) {
    PaperStatus.safe => Tone.ok,
    PaperStatus.look => Tone.look,
    PaperStatus.changed => Tone.bad,
  };
}

/// One detail read from a paper. [was] is set when the value has changed.
class PaperField {
  const PaperField(this.label, this.value, {this.was});

  final String label;
  final String value;
  final String? was;

  bool get isChanged => was != null;
}

/// One copy of a paper in one place.
class PaperCopy {
  const PaperCopy({
    required this.kind,
    required this.placeName,
    required this.path,
    this.state = CopyState.same,
  });

  final PlaceKind kind;
  final String placeName;
  final String path;
  final CopyState state;
}

class Paper {
  const Paper({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.status,
    required this.statusText,
    required this.fields,
    required this.copies,
    this.brokenSegment = 2,
    this.sealWarnSegment,
    this.verdict,
  });

  final String id;
  final String title;
  final String shortTitle;
  final PaperStatus status;
  final String statusText;
  final List<PaperField> fields;
  final List<PaperCopy> copies;

  /// Which piece of the seal ring turns red when a detail has changed.
  final int brokenSegment;

  /// Which piece turns amber when the paper is only "worth a look".
  final int? sealWarnSegment;

  /// Set when a copy differs from the original.
  final PaperVerdict? verdict;

  bool get hasChange => fields.any((f) => f.isChanged);

  /// How many details still match the original.
  int get matchingDetails => fields.where((f) => !f.isChanged).length;
}

/// An entry on the Alerts screen. [group] is `urgent`, `soon` or `info`.
class AlertItem {
  const AlertItem({
    required this.group,
    required this.tone,
    required this.title,
    required this.text,
    this.paperId,
    this.when,
  });

  final String group;
  final Tone tone;
  final String title;
  final String text;
  final String? paperId;
  final String? when;
}

/// A phone or laptop that keeps the owner's papers in sync.
class DeviceInfo {
  const DeviceInfo(this.kind, this.name, this.detail, {this.online = true});

  final PlaceKind kind;
  final String name;
  final String detail;
  final bool online;
}

class CloudAccount {
  const CloudAccount(this.name, this.account, {this.connected = false});

  final String name;
  final String account;
  final bool connected;
}

/// A folder or cloud account Docuveil is allowed to look at.
class WatchedPlace {
  const WatchedPlace(this.kind, this.name, this.path, {this.on = true});

  final PlaceKind kind;
  final String name;
  final String path;
  final bool on;
}

/// A renewal or other date to remember.
class DateItem {
  const DateItem({
    required this.month,
    required this.day,
    required this.title,
    required this.when,
    required this.tone,
  });

  final String month;
  final String day;
  final String title;
  final String when;
  final Tone tone;
}
