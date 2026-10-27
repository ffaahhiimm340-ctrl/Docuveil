import 'dart:math' as math;

import 'normalize.dart';

/// equivalent: same person written differently (initials, order, case,
/// punctuation). likelyProblem: probably the same person but an official
/// check may stumble (spelling, missing name, surname change). blocking:
/// different names.
enum MatchLevel { equivalent, likelyProblem, blocking }

class NameMatch {
  const NameMatch(this.level, this.reason);

  final MatchLevel level;
  final String reason;
}

const _titles = {
  'shri', 'sri', 'smt', 'shrimati', 'mr', 'mrs', 'ms', 'miss', 'dr', 'late',
};

/// Common transliteration families; each maps to one canonical spelling.
const _canonical = {
  'mohammed': 'mohammad', 'muhammad': 'mohammad', 'mohd': 'mohammad',
  'mohamed': 'mohammad', 'md': 'mohammad',
  'kumaar': 'kumar', 'kumari': 'kumari',
  'sharma': 'sharma', 'sarma': 'sharma',
  'singh': 'singh', 'sing': 'singh',
  'patel': 'patel', 'patil': 'patil',
  'lakshmi': 'laxmi', 'laxmi': 'laxmi', 'lakshmy': 'laxmi',
  'krishna': 'krishna', 'krushna': 'krishna', 'krisna': 'krishna',
  'venkat': 'venkata', 'venkata': 'venkata',
};

/// Apostrophes join (D'Souza -> dsouza); full stops split (R.K. -> r k).
List<String> nameTokens(String name) => normalizeText(
  name.replaceAll(RegExp(r"['’`]"), ''),
).split(' ').where((t) => t.isNotEmpty && !_titles.contains(t)).toList();

double jaroWinkler(String s1, String s2) {
  if (s1 == s2) return 1;
  final l1 = s1.length, l2 = s2.length;
  if (l1 == 0 || l2 == 0) return 0;
  final window = math.max(0, math.max(l1, l2) ~/ 2 - 1);
  final m1 = List.filled(l1, false), m2 = List.filled(l2, false);
  var matches = 0;
  for (var i = 0; i < l1; i++) {
    final lo = math.max(0, i - window), hi = math.min(l2 - 1, i + window);
    for (var j = lo; j <= hi; j++) {
      if (!m2[j] && s1[i] == s2[j]) {
        m1[i] = m2[j] = true;
        matches++;
        break;
      }
    }
  }
  if (matches == 0) return 0;
  var t = 0, k = 0;
  for (var i = 0; i < l1; i++) {
    if (!m1[i]) continue;
    while (!m2[k]) {
      k++;
    }
    if (s1[i] != s2[k]) t++;
    k++;
  }
  final m = matches.toDouble();
  final jaro = (m / l1 + m / l2 + (m - t / 2) / m) / 3;
  var prefix = 0;
  for (var i = 0; i < math.min(4, math.min(l1, l2)); i++) {
    if (s1[i] != s2[i]) break;
    prefix++;
  }
  return jaro + prefix * 0.1 * (1 - jaro);
}

bool _exactOrInitial(String a, String b) {
  if (a == b) return true;
  if (a.length == 1 && b.startsWith(a)) return true;
  if (b.length == 1 && a.startsWith(b)) return true;
  return false;
}

String _canon(String t) => _canonical[t] ?? t;

bool _similar(String a, String b) {
  if (_exactOrInitial(a, b)) return true;
  if (a.length == 1 || b.length == 1) return false;
  return _canon(a) == _canon(b) || jaroWinkler(a, b) >= 0.88;
}

/// Is there an injective mapping from every token of [small] to a distinct
/// token of [big] where each pair satisfies [ok]?
bool _assign(
  List<String> small,
  List<String> big,
  bool Function(String, String) ok,
) {
  final used = List.filled(big.length, false);
  bool go(int i) {
    if (i == small.length) return true;
    for (var j = 0; j < big.length; j++) {
      if (!used[j] && ok(small[i], big[j])) {
        used[j] = true;
        if (go(i + 1)) return true;
        used[j] = false;
      }
    }
    return false;
  }

  return go(0);
}

/// Compare two Indian-style personal names.
NameMatch compareNames(String a, String b) {
  final ta = nameTokens(a), tb = nameTokens(b);
  if (ta.isEmpty || tb.isEmpty) {
    return const NameMatch(MatchLevel.blocking, 'a name is missing');
  }
  if (ta.join(' ') == tb.join(' ')) {
    return NameMatch(
      MatchLevel.equivalent,
      a.trim() == b.trim() ? 'identical' : 'only case or punctuation differs',
    );
  }
  final sameSize = ta.length == tb.length;
  if (sameSize && (List.of(ta)..sort()).join(' ') == (List.of(tb)..sort()).join(' ')) {
    return const NameMatch(MatchLevel.equivalent, 'name order differs');
  }
  if (sameSize && _assign(ta, tb, _exactOrInitial)) {
    return const NameMatch(
      MatchLevel.equivalent,
      'an initial stands for a full name',
    );
  }
  final small = ta.length <= tb.length ? ta : tb;
  final big = ta.length <= tb.length ? tb : ta;
  if (!sameSize && _assign(small, big, _exactOrInitial)) {
    return const NameMatch(
      MatchLevel.likelyProblem,
      'one document leaves out part of the name',
    );
  }
  if (_assign(small, big, _similar)) {
    return NameMatch(
      MatchLevel.likelyProblem,
      sameSize ? 'spelling differs' : 'spelling differs and part of the name is left out',
    );
  }
  // Same first name, different surname: maiden vs married name.
  if (_similar(ta.first, tb.first) && !_similar(ta.last, tb.last)) {
    return const NameMatch(
      MatchLevel.likelyProblem,
      'surname differs (maiden vs married name?)',
    );
  }
  return const NameMatch(MatchLevel.blocking, 'names are different');
}
