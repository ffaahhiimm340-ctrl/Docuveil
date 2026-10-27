import 'dart:math' as math;

/// Everything the score needs to know about one document.
class AvailabilityInput {
  const AvailabilityInput({
    required this.copies,
    this.daysSinceBackup,
    this.integrityOk = true,
  });

  /// Copies on distinct devices or clouds.
  final int copies;

  /// Null means never backed up.
  final int? daysSinceBackup;

  /// False when the last check found a tampered or unreadable copy.
  final bool integrityOk;
}

enum Urgency { immediate, batched, low }

/// Weights are a first guess; the user-ranking study (weeks 11-12) is what
/// validates or tunes them.
class AvailabilityWeights {
  const AvailabilityWeights({
    this.copies = 0.4,
    this.backup = 0.3,
    this.integrity = 0.3,
  });

  final double copies;
  final double backup;
  final double integrity;
}

/// 0 (fragile) to 100 (well protected).
double availabilityScore(
  AvailabilityInput i, {
  AvailabilityWeights w = const AvailabilityWeights(),
}) {
  final copies = math.min(i.copies, 3) / 3;
  final days = i.daysSinceBackup;
  final backup = days == null ? 0.0 : math.max(0.0, 1 - days / 90);
  final integrity = i.integrityOk ? 1.0 : 0.0;
  return 100 *
      (w.copies * copies + w.backup * backup + w.integrity * integrity);
}

/// The less available a document is, the less room there is for a tamper
/// alert to wait: a tampered document with no good copy is urgent.
Urgency alertUrgency(double score, {required bool tampered}) {
  if (!tampered) return Urgency.low;
  if (score < 50) return Urgency.immediate;
  if (score < 80) return Urgency.batched;
  return Urgency.low;
}
