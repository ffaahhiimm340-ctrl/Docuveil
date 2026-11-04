import 'package:docuveil_engine/docuveil_engine.dart' show DocType, ExtractedDoc;

import '../models/models.dart';
import 'copy_check.dart';
import '../theme/app_colors.dart';
import 'derived.dart';
import 'safety_center.dart';
import 'sync_service.dart';
import 'vault.dart';

// NOTE: rebuilt to match the screens (the original was never committed, see
// PR #3). Everything here is synthetic: a fictional person, "Asha Verma".
// Papers are not hand-written: each copy's fields go through the engine
// (checkPaper), which decides what changed.

/// Fictional content the screens show until they read the real vault.
class SampleData {
  SampleData._();

  static const userName = 'Asha';

  static const _phone = 'Documents / Docuveil';
  static const _laptop = r'C:\Users\Asha\Documents\Docuveil';
  static const _drive = 'My Drive / Docuveil';

  static CopySnapshot _copy(
    PlaceKind kind,
    String file,
    String sha,
    ExtractedDoc doc, {
    bool original = false,
  }) => CopySnapshot(
    kind: kind,
    placeName: switch (kind) {
      PlaceKind.phone => 'This phone',
      PlaceKind.laptop => "Asha's laptop",
      PlaceKind.cloud => 'Google Drive',
    },
    path: switch (kind) {
      PlaceKind.phone => '$_phone / $file',
      PlaceKind.laptop => '$_laptop\\$file',
      PlaceKind.cloud => '$_drive / $file',
    },
    sha256: sha,
    doc: doc,
    original: original,
  );

  static ExtractedDoc _doc(String id, DocType t, Map<String, String> f) =>
      ExtractedDoc(
        id: id,
        type: t,
        fields: f,
        text: 'SYNTHETIC SAMPLE ${f.entries.map((e) => '${e.key} ${e.value}').join(' ')}',
      );

  static final List<PaperSource> sources = [
    PaperSource(
      id: 'marksheet',
      title: 'Marksheet, Semester 2',
      shortTitle: 'Marksheet',
      labels: const {'cgpa': 'CGPA, Semester 2'},
      copies: [
        _copy(
          PlaceKind.laptop,
          'Marksheet_Sem2.pdf',
          'sha-marksheet-v1',
          _doc('marksheet', DocType.marksheet, {
            'name': 'Asha Rajesh Verma',
            'semester': '2',
            'seat_number': 'S482913',
            'cgpa': '8.74',
          }),
          original: true,
        ),
        // Re-scanned on the phone: different file, same details.
        _copy(
          PlaceKind.phone,
          'Marksheet_Sem2.pdf',
          'sha-marksheet-rescan',
          _doc('marksheet', DocType.marksheet, {
            'name': 'ASHA RAJESH VERMA',
            'semester': '2',
            'seat_number': 'S482913',
            'cgpa': '8.740',
          }),
        ),
        // Edited on Google Drive.
        _copy(
          PlaceKind.cloud,
          'Marksheet_Sem2.pdf',
          'sha-marksheet-edited',
          _doc('marksheet', DocType.marksheet, {
            'name': 'Asha Rajesh Verma',
            'semester': '2',
            'seat_number': 'S482913',
            'cgpa': '9.40',
          }),
        ),
      ],
    ),
    PaperSource(
      id: 'aadhaar',
      title: 'Aadhaar card',
      shortTitle: 'Aadhaar',
      copies: [
        for (final (kind, original) in [
          (PlaceKind.phone, true),
          (PlaceKind.laptop, false),
        ])
          _copy(
            kind,
            'Aadhaar.pdf',
            'sha-aadhaar',
            _doc('aadhaar', DocType.aadhaar, {
              'name': 'Asha R. Verma',
              'dob': '04 Jul 2001',
              'father_name': 'Rajesh Verma',
            }),
            original: original,
          ),
      ],
    ),
    PaperSource(
      id: 'pan',
      title: 'PAN card',
      shortTitle: 'PAN card',
      copies: [
        for (final (kind, original) in [
          (PlaceKind.laptop, true),
          (PlaceKind.cloud, false),
        ])
          _copy(
            kind,
            'PAN.pdf',
            'sha-pan',
            _doc('pan', DocType.pan, {
              'name': 'Asha Rajesh Verma',
              'dob': '04 Jul 2001',
              'father_name': 'R Verma',
            }),
            original: original,
          ),
      ],
    ),
    PaperSource(
      id: 'certificate',
      title: 'Degree certificate',
      shortTitle: 'Degree certificate',
      status: PaperStatus.look,
      statusText: 'Worth a look: one copy only',
      sealWarnSegment: 3,
      copies: [
        _copy(
          PlaceKind.laptop,
          'Degree.pdf',
          'sha-degree',
          _doc('certificate', DocType.certificate, {
            'name': 'Asha Rajesh Varma',
            'degree': 'B.Sc. Computer Science',
            'year': '2023',
          }),
          original: true,
        ),
      ],
    ),
    PaperSource(
      id: 'insurance',
      title: 'Health insurance policy',
      shortTitle: 'Insurance',
      statusText: 'Renews 12 Mar',
      copies: [
        _copy(
          PlaceKind.phone,
          'Insurance.pdf',
          'sha-insurance',
          _doc('insurance', DocType.insurance, {
            'policy_number': 'POL48291355',
            'sum_assured': '500000',
            'renewal_date': '12/03/2027',
          }),
          original: true,
        ),
        // Exported again by the insurer's site: amount written differently.
        _copy(
          PlaceKind.cloud,
          'Insurance.pdf',
          'sha-insurance-export',
          _doc('insurance', DocType.insurance, {
            'policy_number': 'POL48291355',
            'sum_assured': 'Rs. 5,00,000',
            'renewal_date': '12 Mar 2027',
          }),
        ),
      ],
    ),
  ];

  /// Sample papers plus everything the owner has added.
  static List<PaperSource> get allSources => [
    ...sources,
    for (final v in Vault.docs.value)
      if (!v.isDemo) sourceFromVault(v),
  ];

  static List<Paper> get papers => [for (final s in allSources) checkPaper(s)];

  static Paper paperById(String id) {
    final all = papers;
    return all.firstWhere((p) => p.id == id, orElse: () => all.first);
  }

  static List<AlertItem> get alerts => [
    if (DecoyGuard.alarm.value != null)
      AlertItem(
        group: 'urgent',
        tone: Tone.bad,
        title: 'Ransomware guard warning',
        text: '${DecoyGuard.alarm.value} Stop syncing and check this computer.',
      ),
    ...syncAlerts(SyncService.instance.alerts.value),
    ...alertsFrom(papers, renewalsFrom(allSources, DateTime.now())),
  ];

  static int get urgentCount => alerts.where((a) => a.group == 'urgent').length;

  static const devices = [
    DeviceInfo(PlaceKind.phone, "Asha's phone", 'Android'),
    DeviceInfo(PlaceKind.laptop, "Asha's laptop", 'Windows · synced 2 min ago'),
  ];

  static const clouds = [
    CloudAccount('Google Drive', 'asha.verma@example.com', connected: true),
    CloudAccount('OneDrive', 'Not connected'),
  ];

  static const watchedPlaces = [
    WatchedPlace(PlaceKind.phone, 'Documents', 'Documents / Docuveil'),
    WatchedPlace(PlaceKind.phone, 'Downloads', 'Download', on: false),
    WatchedPlace(PlaceKind.laptop, 'Documents', r'C:\Users\Asha\Documents'),
    WatchedPlace(PlaceKind.cloud, 'Google Drive', 'My Drive / Docuveil'),
  ];

  /// Renewal dates from the papers themselves, soonest first.
  static List<DateItem> get dates => [
    for (final r in renewalsFrom(allSources, DateTime.now())) r.$1,
  ];
}
