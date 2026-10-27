import 'availability.dart';
import 'fingerprint.dart';

/// Another device's copy of a document differs from this device's copy.
///
/// The alert cannot say which copy is the bad one: only that they disagree,
/// and which fields. The app shows both devices so the owner can decide.
class DivergenceAlert {
  const DivergenceAlert({
    required this.docTag,
    required this.changedFields,
    required this.remoteDevice,
    required this.score,
    required this.urgency,
  });

  final String docTag;

  /// Field names (mapped back locally from the server-opaque tags).
  final List<String> changedFields;
  final String remoteDevice;
  final double score;
  final Urgency urgency;

  String summary() =>
      'Your copy on $remoteDevice differs from this one in: '
      '${changedFields.join(', ')}.';
}

/// One entry from the relay's `/changes` response.
class RemoteEntry {
  const RemoteEntry(this.seq, this.deviceId, this.fingerprint);

  factory RemoteEntry.fromJson(Map<String, dynamic> j) => RemoteEntry(
    j['seq'] as int,
    j['device_id'] as String,
    FingerprintSet.fromJson(j),
  );

  final int seq;
  final String deviceId;
  final FingerprintSet fingerprint;
}

/// Compare this device's fingerprints with entries from the owner's other
/// devices and raise an alert for each document that disagrees.
///
/// [local] is keyed by doc tag. [knownFields] maps tags back to field names;
/// [availability] gives the per-document input for the urgency score. Only
/// the newest entry per (device, document) counts.
List<DivergenceAlert> detectDivergence(
  List<int> key, {
  required Map<String, FingerprintSet> local,
  required Iterable<RemoteEntry> remote,
  required Iterable<String> knownFields,
  required AvailabilityInput Function(String docTag) availability,
}) {
  final newest = <String, RemoteEntry>{};
  for (final e in remote) {
    final k = '${e.deviceId}\u0000${e.fingerprint.docTag}';
    final cur = newest[k];
    if (cur == null || e.seq > cur.seq) newest[k] = e;
  }
  final alerts = <DivergenceAlert>[];
  for (final e in newest.values) {
    final mine = local[e.fingerprint.docTag];
    if (mine == null) continue; // this device does not hold that document
    final tags = changedFieldTags(mine, e.fingerprint);
    if (tags.isEmpty) continue;
    final score = availabilityScore(availability(mine.docTag));
    alerts.add(
      DivergenceAlert(
        docTag: mine.docTag,
        changedFields: namesForTags(key, mine.docTag, tags, knownFields),
        remoteDevice: e.deviceId,
        score: score,
        urgency: alertUrgency(score, tampered: true),
      ),
    );
  }
  alerts.sort((a, b) => a.urgency.index.compareTo(b.urgency.index));
  return alerts;
}
