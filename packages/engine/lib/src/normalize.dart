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

/// The digits of an amount or number written the Indian way (`Rs. 10,00,000`,
/// `₹1000000`), or null if [s] is not a plain number.
String? _plainNumber(String s) {
  final t = s
      .trim()
      .replaceFirst(RegExp(r'^(rs\.?|inr|₹)', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\s,]'), '');
  return RegExp(r'^-?\d+(\.\d+)?$').hasMatch(t) ? t : null;
}

/// `8.740` and `8.74` are the same number; so are `10,00,000` and `1000000`.
/// Non-numbers fall back to text.
String normalizeNumber(String s) {
  final t = _plainNumber(s);
  if (t == null) return normalizeText(s);
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
    .replaceAll('L', '1')
    .replaceAll('S', '5')
    .replaceAll('B', '8')
    .replaceAll('Z', '2');

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
  if (_plainNumber(value) != null) return normalizeNumber(value);
  return normalizeText(value);
}

/// Pairs of characters OCR commonly confuses. Digit-to-digit is never here,
/// so a changed digit is always a real change.
const _ocrPairs = {
  'o0', '0o', 'i1', '1i', 'l1', '1l', 'il', 'li', 's5', '5s', 'b8', '8b',
  'z2', '2z', 'g6', '6g', 'ec', 'ce', 'uv', 'vu',
};

/// True if [a] and [b] (already normalised) differ only by up to two
/// substitutions of OCR-confusable characters.
bool ocrNear(String a, String b) {
  if (a == b) return false;
  // "rn" and "m" look alike in print; compare with both written as "m".
  a = a.replaceAll('rn', 'm');
  b = b.replaceAll('rn', 'm');
  if (a == b) return true;
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] == b[i]) continue;
    if (!_ocrPairs.contains('${a[i]}${b[i]}')) return false;
    if (++diff > 2) return false;
  }
  return true;
}

const _labels = {
  'dob': 'Date of birth',
  'father_name': "Father's name",
  'cgpa': 'CGPA',
};

/// Human label for a field key: `expiry_date` -> `Expiry date`.
String fieldLabel(String key) {
  final known = _labels[key];
  if (known != null) return known;
  final s = key.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
