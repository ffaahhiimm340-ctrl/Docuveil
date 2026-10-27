import '../models/models.dart';
import '../theme/app_colors.dart';

// NOTE: rebuilt to match the screens (the original was never committed, see
// PR #3). Everything here is synthetic: a fictional person, "Asha Verma".

/// Fictional content the screens show until they read the real vault.
class SampleData {
  SampleData._();

  static const userName = 'Asha';

  static const _phone = 'Documents / Docuveil';
  static const _laptop = r'C:\Users\Asha\Documents\Docuveil';
  static const _drive = 'My Drive / Docuveil';

  static PaperCopy _copy(
    PlaceKind kind,
    String file,
    CopyState state,
  ) => switch (kind) {
    PlaceKind.phone => PaperCopy(
      kind: kind,
      placeName: 'This phone',
      path: '$_phone / $file',
      state: state,
    ),
    PlaceKind.laptop => PaperCopy(
      kind: kind,
      placeName: "Asha's laptop",
      path: '$_laptop\\$file',
      state: state,
    ),
    PlaceKind.cloud => PaperCopy(
      kind: kind,
      placeName: 'Google Drive',
      path: '$_drive / $file',
      state: state,
    ),
  };

  static final List<Paper> papers = [
    Paper(
      id: 'marksheet',
      title: 'Marksheet, Semester 2',
      shortTitle: 'Marksheet',
      status: PaperStatus.changed,
      statusText: 'Changed: 1 detail',
      brokenSegment: 3,
      fields: const [
        PaperField('Name', 'Asha Rajesh Verma'),
        PaperField('Semester', '2'),
        PaperField('Seat number', 'S482913'),
        PaperField('CGPA, Semester 2', '9.40', was: '8.74'),
      ],
      copies: [
        _copy(PlaceKind.laptop, 'Marksheet_Sem2.pdf', CopyState.original),
        _copy(PlaceKind.phone, 'Marksheet_Sem2.pdf', CopyState.same),
        _copy(PlaceKind.cloud, 'Marksheet_Sem2.pdf', CopyState.changed),
      ],
    ),
    Paper(
      id: 'aadhaar',
      title: 'Aadhaar card',
      shortTitle: 'Aadhaar',
      status: PaperStatus.safe,
      statusText: 'Matches your original',
      fields: const [
        PaperField('Name', 'Asha R. Verma'),
        PaperField('Date of birth', '04 Jul 2001'),
        PaperField("Father's name", 'Rajesh Verma'),
      ],
      copies: [
        _copy(PlaceKind.phone, 'Aadhaar.pdf', CopyState.original),
        _copy(PlaceKind.laptop, 'Aadhaar.pdf', CopyState.same),
      ],
    ),
    Paper(
      id: 'pan',
      title: 'PAN card',
      shortTitle: 'PAN card',
      status: PaperStatus.safe,
      statusText: 'Matches your original',
      fields: const [
        PaperField('Name', 'Asha Rajesh Verma'),
        PaperField('Date of birth', '04 Jul 2001'),
        PaperField("Father's name", 'R Verma'),
      ],
      copies: [
        _copy(PlaceKind.laptop, 'PAN.pdf', CopyState.original),
        _copy(PlaceKind.cloud, 'PAN.pdf', CopyState.same),
      ],
    ),
    Paper(
      id: 'certificate',
      title: 'Degree certificate',
      shortTitle: 'Degree certificate',
      status: PaperStatus.look,
      statusText: 'Worth a look: one copy only',
      sealWarnSegment: 3,
      fields: const [
        PaperField('Name', 'Asha Rajesh Varma'),
        PaperField('Degree', 'B.Sc. Computer Science'),
        PaperField('Year', '2023'),
      ],
      copies: [_copy(PlaceKind.laptop, 'Degree.pdf', CopyState.original)],
    ),
    Paper(
      id: 'insurance',
      title: 'Health insurance policy',
      shortTitle: 'Insurance',
      status: PaperStatus.safe,
      statusText: 'Renews 12 Mar',
      fields: const [
        PaperField('Policy number', 'POL48291355'),
        PaperField('Sum assured', '5,00,000'),
        PaperField('Renewal date', '12 Mar 2027'),
      ],
      copies: [
        _copy(PlaceKind.phone, 'Insurance.pdf', CopyState.original),
        _copy(PlaceKind.cloud, 'Insurance.pdf', CopyState.same),
      ],
    ),
  ];

  static Paper paperById(String id) =>
      papers.firstWhere((p) => p.id == id, orElse: () => papers.first);

  static const alerts = [
    AlertItem(
      group: 'urgent',
      tone: Tone.bad,
      title: 'Marksheet changed on Google Drive',
      text: 'CGPA, Semester 2 went from 8.74 to 9.40. Your laptop copy is the original.',
      paperId: 'marksheet',
      when: 'Today, 9:12 am',
    ),
    AlertItem(
      group: 'soon',
      tone: Tone.look,
      title: 'Health insurance renews on 12 Mar',
      text: 'Renew in the next few months to stay covered.',
      paperId: 'insurance',
    ),
    AlertItem(
      group: 'soon',
      tone: Tone.look,
      title: 'Degree certificate has only one copy',
      text: 'It is only on your laptop. Add a backup.',
      paperId: 'certificate',
    ),
    AlertItem(
      group: 'info',
      tone: Tone.ok,
      title: 'Your laptop is in sync',
      text: 'Last check: 2 minutes ago.',
    ),
  ];

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

  static const dates = [
    DateItem(
      month: 'MAR',
      day: '12',
      title: 'Health insurance renews',
      when: 'In 4 months',
      tone: Tone.look,
    ),
    DateItem(
      month: 'JUL',
      day: '04',
      title: 'Passport application window',
      when: 'In 8 months',
      tone: Tone.brand,
    ),
  ];
}
