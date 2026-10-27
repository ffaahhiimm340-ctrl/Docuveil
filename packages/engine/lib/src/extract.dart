import 'models.dart';

/// Reads the fields the engine compares from a document's text (from a PDF
/// text layer or OCR). Rule-based, per document type, line by line.
///
/// Values are returned as printed (the engine normalises later), except that
/// OCR look-alike letters inside numbers and dates are folded back to digits,
/// since a printed number never contains them.
Map<String, String> extractFields(DocType type, String text) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final x = _Lines(lines);
  final out = <String, String>{};
  void put(String key, String? v) {
    if (v != null && v.trim().isNotEmpty) out[key] = v.trim();
  }

  switch (type) {
    case DocType.aadhaar:
      final dobAt = x.indexOf(_label(r'(year of birth\s*/\s*)?(dob|date of birth)'));
      put('dob', x.after(dobAt, _date));
      // The name is printed without a label, on the line above the birth date.
      if (dobAt > 0) put('name', _nameOnly(lines[dobAt - 1]));
      put('gender', x.find(_gender));
      put('id_number', x.find(_aadhaarNo));
      put('father_name', x.find(_relation));
    case DocType.pan:
      put('id_number', x.find(_panNo));
      put('name', x.valueOf(_label(r'name'), exclude: _label(r"father'?s? ?name")));
      put('father_name', x.valueOf(_label(r"father'?s? ?name")));
      put('dob', x.valueOf(_label(r'date of birth'), pattern: _date));
    case DocType.marksheet:
      put('name', x.valueOf(_label(r'(name of the student|student name|name)')));
      put('seat_number', x.valueOf(_label(r'(seat no\.?|seat number|roll no\.?)')));
      put('semester', _semester(x.valueOf(_label(r'semester'))));
      put('dob', x.valueOf(_label(r'date of birth'), pattern: _date));
      put('cgpa', x.valueOf(_label(r'(sgpa\s*/\s*cgpa|cumulative gpa|cgpa)'), pattern: _gpa));
      if (lines.isNotEmpty) put('university', _titleCase(lines.first));
    case DocType.passport:
      final surname = x.valueOf(_label(r'surname'));
      final given = x.valueOf(_label(r'given name\(?s?\)?'));
      if (surname != null || given != null) {
        put('name', [given, surname].whereType<String>().join(' '));
      }
      put('gender', x.valueOf(_label(r'sex'), pattern: RegExp(r'\b[MFX]\b')));
      put('dob', x.valueOf(_label(r'date of birth'), pattern: _date));
      put('id_number', x.valueOf(_label(r'passport no\.?'), pattern: _passportNo));
      put('expiry_date', x.valueOf(_label(r'date of expiry'), pattern: _date));
      put('father_name', x.valueOf(_label(r'name of father( / legal guardian)?')));
    case DocType.insurance:
      put('policy_number', x.valueOf(_label(r'policy (no\.?|number)')));
      put('name', x.valueOf(_label(r'(policyholder name|name of the insured|proposer name)')));
      put('sum_assured', x.valueOf(_label(r'sum (insured|assured)'), pattern: _amount));
      put('expiry_date', x.valueOf(_label(r'(policy expiry date|valid till|expiry date)'), pattern: _date));
      put('nominee', x.valueOf(_label(r'nominee')));
      if (lines.isNotEmpty) put('insurer', lines.first);
    case DocType.certificate:
      put('name', x.valueOf(_label(r'(this is to certify that|name)')));
      put('degree', x.valueOf(_label(r'degree')));
      put('year', x.valueOf(_label(r'year'), pattern: RegExp(r'\b(19|20)\d\d\b')));
  }
  return out;
}

// --- OCR folding ----------------------------------------------------------

/// Undo letter-for-digit confusions in a string that should be numeric.
String _digits(String s) => s
    .replaceAll(RegExp('[Oo]'), '0')
    .replaceAll(RegExp('[Il|]'), '1')
    .replaceAll('S', '5')
    .replaceAll('B', '8');

// --- patterns ---------------------------------------------------------------

const _d = '[0-9OoIl|SB]'; // a digit, or a letter OCR prints for one
final _date = RegExp(
  '\\b($_d{1,2}[/\\-.]$_d{1,2}[/\\-.]$_d{4}|$_d{1,2} [A-Za-z]{3,9} $_d{4})\\b',
);
final _gpa = RegExp('\\b$_d{1,2}\\.$_d{1,2}\\b');
final _aadhaarNo = RegExp('\\b$_d{4} ?$_d{4} ?$_d{4}\\b');
final _panNo = RegExp(r'\b[A-Z]{5}[0-9OIlSB]{4}[A-Z]\b');
final _passportNo = RegExp('\\b[A-Z]$_d{7}\\b');
final _amount = RegExp(r'((rs\.?|inr|₹)\s*)?[0-9OoIlSB][0-9OoIlSB,]*', caseSensitive: false);
final _gender = RegExp(r'^(male|female|transgender)$', caseSensitive: false);
final _relation = RegExp(r'^(s|d|c|w)\s*/\s*o\s*:?\s*([^,]+)', caseSensitive: false);

/// Letters OCR often prints as something else, and what it prints.
const _looksLike = {
  'm': '(?:m|rn)',
  'o': '[o0]',
  'l': '[l1i|]',
  'i': '[il1|]',
  's': '[s5]',
  'e': '[ec]',
  'b': '[b8]',
  'g': '[g6]',
  'z': '[z2]',
};

/// A label at the start of a line, tolerant of OCR confusions: each letter
/// in [body] also matches its look-alikes ("Semester" matches "Scmester").
RegExp _label(String body) {
  final out = StringBuffer('^');
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    final escaped = i > 0 && body[i - 1] == '\\';
    out.write(!escaped && _looksLike.containsKey(c) ? _looksLike[c] : c);
  }
  out.write('(?![a-z0-9])');
  return RegExp(out.toString(), caseSensitive: false);
}

String? _clean(String? v, RegExp? pattern) {
  if (v == null) return null;
  if (pattern == null) return v;
  final m = pattern.firstMatch(v);
  if (m == null) return null;
  final s = m.group(0)!;
  // Numbers and dates: fold look-alike letters back to digits.
  if (identical(pattern, _date)) {
    return s.contains(RegExp('[A-Za-z]{3}'))
        ? s.replaceFirstMapped(
            RegExp(r'^(\S+)( [A-Za-z]{3,9} )(\S+)$'),
            (m) => '${_digits(m[1]!)}${m[2]}${_digits(m[3]!)}',
          )
        : _digits(s);
  }
  if (identical(pattern, _gpa) || identical(pattern, _passportNo)) {
    return identical(pattern, _passportNo) ? s[0] + _digits(s.substring(1)) : _digits(s);
  }
  if (identical(pattern, _amount)) {
    final prefix = RegExp(r'^((rs\.?|inr|₹)\s*)', caseSensitive: false).firstMatch(s)?.group(0) ?? '';
    return prefix + _digits(s.substring(prefix.length));
  }
  return s;
}

String? _nameOnly(String line) =>
    RegExp(r'^[A-Za-z .]+$').hasMatch(line) && line.split(' ').length >= 2 ? line : null;

String? _semester(String? v) {
  if (v == null) return null;
  const roman = {'I': '1', 'II': '2', 'III': '3', 'IV': '4', 'V': '5', 'VI': '6', 'VII': '7', 'VIII': '8'};
  final t = v.trim().toUpperCase().replaceAll('L', 'I').replaceAll('1', 'I');
  if (roman.containsKey(t)) return roman[t];
  final n = _digits(v.trim());
  return RegExp(r'^\d+$').hasMatch(n) ? n : v.trim();
}

String _titleCase(String s) => s
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');

class _Lines {
  _Lines(this.lines);

  final List<String> lines;

  /// Where [label] ends on line [i], or null if line [i] does not start with it.
  int? _labelEnd(RegExp label, int i) => label.firstMatch(lines[i])?.end;

  int indexOf(RegExp label) {
    for (var i = 0; i < lines.length; i++) {
      if (_labelEnd(label, i) != null) return i;
    }
    return -1;
  }

  /// Value printed after [label]: on the same line after the label and a
  /// separator, else on the next line.
  String? valueOf(RegExp label, {RegExp? exclude, RegExp? pattern}) {
    for (var i = 0; i < lines.length; i++) {
      final end = _labelEnd(label, i);
      if (end == null) continue;
      if (exclude != null && _labelEnd(exclude, i) != null) continue;
      final rest = lines[i]
          .substring(end)
          .replaceFirst(RegExp(r'^\s*[:\-]?\s*'), '');
      final v = rest.isNotEmpty ? rest : (i + 1 < lines.length ? lines[i + 1] : null);
      final c = _clean(v, pattern);
      if (c != null) return c;
    }
    return null;
  }

  /// Value found on the line at [at] (after its label) or the next line.
  String? after(int at, RegExp pattern) {
    if (at < 0) return null;
    for (final l in [lines[at], if (at + 1 < lines.length) lines[at + 1]]) {
      final c = _clean(l, pattern);
      if (c != null) return c;
    }
    return null;
  }

  String? find(RegExp pattern) {
    for (final l in lines) {
      final m = pattern.firstMatch(l);
      if (m == null) continue;
      if (identical(pattern, _relation)) return m.group(2)!.trim();
      if (identical(pattern, _aadhaarNo)) return _digits(m.group(0)!);
      if (identical(pattern, _panNo)) {
        final s = m.group(0)!;
        return s.substring(0, 5) + _digits(s.substring(5, 9)) + s.substring(9);
      }
      return m.group(0);
    }
    return null;
  }
}
