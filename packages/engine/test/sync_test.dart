import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:test/test.dart';

void main() {
  final key = List<int>.generate(32, (i) => i);
  ExtractedDoc marks(String cgpa, {String id = 'm1'}) => ExtractedDoc(
    id: id,
    type: DocType.marksheet,
    fields: {'name': 'Rahul Sharma', 'cgpa': cgpa},
  );
  const low = AvailabilityInput(copies: 1);
  const high = AvailabilityInput(copies: 3, daysSinceBackup: 1);

  test('a differing copy on another device raises an alert naming the field', () {
    final mine = fingerprint(key, marks('8.74'));
    final theirs = fingerprint(key, marks('9.40'));
    final alerts = detectDivergence(
      key,
      local: {mine.docTag: mine},
      remote: [RemoteEntry(1, 'phone', theirs)],
      knownFields: const ['name', 'cgpa'],
      availability: (_) => low,
    );
    expect(alerts, hasLength(1));
    expect(alerts.single.changedFields, ['cgpa']);
    expect(alerts.single.remoteDevice, 'phone');
    expect(alerts.single.urgency, Urgency.immediate);
    expect(alerts.single.summary(), contains('phone'));
  });

  test('identical or merely reformatted copies raise nothing', () {
    final mine = fingerprint(key, marks('8.74'));
    final same = fingerprint(key, marks('8.740'));
    expect(
      detectDivergence(
        key,
        local: {mine.docTag: mine},
        remote: [RemoteEntry(1, 'phone', same)],
        knownFields: const ['name', 'cgpa'],
        availability: (_) => low,
      ),
      isEmpty,
    );
  });

  test('only the newest entry per device and document counts', () {
    final mine = fingerprint(key, marks('8.74'));
    final alerts = detectDivergence(
      key,
      local: {mine.docTag: mine},
      remote: [
        RemoteEntry(1, 'phone', fingerprint(key, marks('9.40'))),
        RemoteEntry(2, 'phone', fingerprint(key, marks('8.74'))), // fixed since
      ],
      knownFields: const ['name', 'cgpa'],
      availability: (_) => low,
    );
    expect(alerts, isEmpty);
  });

  test('a well-protected document is less urgent than a fragile one', () {
    final a = fingerprint(key, marks('8.74', id: 'a'));
    final b = fingerprint(key, marks('8.74', id: 'b'));
    final alerts = detectDivergence(
      key,
      local: {a.docTag: a, b.docTag: b},
      remote: [
        RemoteEntry(1, 'phone', fingerprint(key, marks('9.00', id: 'a'))),
        RemoteEntry(2, 'phone', fingerprint(key, marks('9.00', id: 'b'))),
      ],
      knownFields: const ['name', 'cgpa'],
      availability: (tag) => tag == a.docTag ? high : low,
    );
    expect(alerts.first.docTag, b.docTag); // fragile first
    expect(alerts.first.urgency, Urgency.immediate);
    expect(alerts.last.urgency, Urgency.low);
  });

  test('documents this device does not hold are ignored', () {
    final other = fingerprint(key, marks('9.40', id: 'zzz'));
    expect(
      detectDivergence(
        key,
        local: const {},
        remote: [RemoteEntry(1, 'phone', other)],
        knownFields: const ['name', 'cgpa'],
        availability: (_) => low,
      ),
      isEmpty,
    );
  });

  test('RemoteEntry parses the relay JSON', () {
    final fp = fingerprint(key, marks('8.74'));
    final e = RemoteEntry.fromJson({
      'seq': 3,
      'device_id': 'laptop',
      'doc': fp.docTag,
      'fields': fp.fields,
    });
    expect(e.seq, 3);
    expect(e.fingerprint.docTag, fp.docTag);
  });
}
