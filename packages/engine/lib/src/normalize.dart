/// Lower-case, strip punctuation, collapse whitespace.
String normalizeText(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _months = {
  'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
  'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
  'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9, 'oct': 10,
  'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
};

String _iso(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return '';
  return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
      '${d.toString().padLeft(2, '0')}';
}

/// Canonical `yyyy-mm-dd`. Numeric dates are read day-first (Indian
/// convention). Unrecognised input falls back to [normalizeText].
String normalizeDate(String s) {
  final t = s.trim();
  var m = RegExp(r'^(\d{1,2})[/\-. ](\d{1,2})[/\-. ](\d{4})$').firstMatch(t);
  if (m != null) {
    final r = _iso(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
    if (r.isNotEmpty) return r;
  }
  m = RegExp(r'^(\d{4})[/\-. ](\d{1,2})[/\-. ](\d{1,2})$').firstMatch(t);
  if (m != null) {
    final r = _iso(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (r.isNotEmpty) return r;
  }
  m = RegExp(r'^(\d{1,2})\s*([A-Za-z]{3,9})\.?,?\s*(\d{4})$').firstMatch(t);
  if (m != null) {
    final mon = _months[m[2]!.toLowerCase()];
    if (mon != null) {
      final r = _iso(int.parse(m[3]!), mon, int.parse(m[1]!));
      if (r.isNotEmpty) return r;
    }
  }
  return normalizeText(s);
}

/// `8.740` and `8.74` are the same number. Non-numbers fall back to text.
String normalizeNumber(String s) {
  final t = s.trim().replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t)) return normalizeText(s);
  if (!t.contains('.')) return t;
  return t.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

/// ID numbers: drop spaces/dashes, upper-case, and fold the letter/digit
/// confusions OCR makes on re-scans (O->0, I/L->1). Heuristic: a forger
/// changing a digit does not swap in a letter, so this does not hide real edits.
String normalizeIdNumber(String s) => s
    .toUpperCase()
    .replaceAll(RegExp(r'[\s\-]'), '')
    .replaceAll('O', '0')
    .replaceAll('I', '1')
    .replaceAll('L', '1');

String normalizeGender(String s) {
  final t = normalizeText(s);
  if (t.startsWith('m')) return 'm';
  if (t.startsWith('f')) return 'f';
  if (t.isEmpty) return '';
  return 'o';
}

/// Normalise a value according to what its field key says it is.
String normalizeField(String key, String value) {
  if (key == 'dob' || key.endsWith('_date')) return normalizeDate(value);
  if (key == 'gender') return normalizeGender(value);
  if (key.endsWith('_number')) return normalizeIdNumber(value);
  if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value.trim())) {
    return normalizeNumber(value);
  }
  return normalizeText(value);
}

/// Human label for a field key: `father_name` -> `Father name`.
String fieldLabel(String key) {
  final s = key.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
