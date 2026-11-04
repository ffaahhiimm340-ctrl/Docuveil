import 'models.dart';

/// The fields a paper of each type should have.
const expectedFields = {
  DocType.aadhaar: ['name', 'dob', 'gender', 'father_name', 'id_number'],
  DocType.pan: ['name', 'dob', 'father_name', 'id_number'],
  DocType.marksheet: ['name', 'dob', 'seat_number', 'semester', 'cgpa'],
  DocType.insurance: ['name', 'policy_number', 'sum_assured', 'expiry_date', 'nominee'],
  DocType.certificate: ['name', 'degree', 'year'],
  DocType.passport: ['name', 'dob', 'gender', 'father_name', 'id_number', 'expiry_date'],
};

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
      put('dob', x.valueOf(_label(r'date of b[a-z]*'), pattern: _date));
    case DocType.marksheet:
      put('name', x.valueOf(_label(r'(name of the student|student name|name)', glued: true)));
      put('seat_number', x.valueOf(_label(r'(seat no\.?|seat number|roll no\.?)', glued: true)));
      put('semester', _semester(x.valueOf(_label(r'semester', glued: true))));
      put('dob', x.valueOf(_label(r'date of b[a-z]*'), pattern: _date));
      put('cgpa', x.valueOf(_label(r'(sgpa\s*/\s*cgpa|cumulative gpa|cgpa)'), pattern: _gpa));
      if (lines.isNotEmpty) put('university', _titleCase(lines.first));
    case DocType.passport:
      final surname = x.valueOf(_label(r'surname'));
      final given = x.valueOf(_label(r'given name( \(?s\)?)?'));
      if (surname != null || given != null) {
        put('name', [given, surname].whereType<String>().join(' '));
      }
      put(
        'gender',
        x.find(_sexLine) ?? x.valueOf(_label(r'sex'), pattern: RegExp(r'\b[MFX]\b')),
      );
      put('dob', x.valueOf(_label(r'date of b[a-z]*'), pattern: _date));
      put('id_number', x.valueOf(_label(r'passport no\.?'), pattern: _passportNo));
      put('expiry_date', x.valueOf(_label(r'date of expiry'), pattern: _date));
      put('father_name', x.valueOf(_label(r'name of father( / legal guardian)?')));
    case DocType.insurance:
      put('policy_number', x.valueOf(_label(r'policy (no\.?|number)', glued: true)));
      put('name', x.valueOf(_label(r'(policyholder name|name of the insured|proposer name)', glued: true)));
      put('sum_assured', x.valueOf(_label(r'sum (insured|assured)', glued: true), pattern: _amount));
      put('expiry_date', x.valueOf(_label(r'(policy expiry date|valid till|expiry date)'), pattern: _date));
      put('nominee', x.valueOf(_label(r'nominee', glued: true)));
      if (lines.isNotEmpty) put('insurer', lines.first);
    case DocType.certificate:
      put('name', x.valueOf(_label(r'(this is to certify that|name)')));
      put('degree', x.valueOf(_label(r'(has been awarded the degree of|degree)'), exclude: _label(r'degree certificate')));
      put(
        'year',
        x.valueOf(
          _label(r'(in the year|year)'),
          pattern: RegExp('(?<![0-9])[0-9]{4}(?![0-9])'),
        ),
      );
  }
  return out;
}

// --- OCR folding ----------------------------------------------------------

/// Undo letter-for-digit confusions in a string that should be numeric.
String _digits(String s) => s
    .replaceAll(RegExp('[Oo]'), '0')
    .replaceAll(RegExp('[Iil|]'), '1')
    .replaceAll('S', '5')
    .replaceAll('B', '8');

// --- patterns ---------------------------------------------------------------

const _d = '[0-9OoIil|SB]'; // a digit, or a letter OCR prints for one
// Numbers are bounded by "not a digit" rather than \b, because OCR that drops
// spaces glues them to the label ("DateofBirth17Oct1993").
const _nd = '(?<![0-9])', _ndAfter = '(?![0-9])';
const _sep = '[/\\-.\u2013\u2014\uFFFD]'; // dash-like, or a character OCR garbled
final _date = RegExp(
  '$_nd($_d{1,2}$_sep$_d{1,2}$_sep$_d{4}|$_d{1,2} ?[A-Za-z]{3,9} ?$_d{4})$_ndAfter',
);
final _gpa = RegExp('$_nd$_d{1,2}\\.$_d{1,2}$_ndAfter');
final _aadhaarNo = RegExp('$_nd$_d{4} ?$_d{4} ?$_d{4}$_ndAfter');
final _panNo = RegExp(r'\b[A-Z]{5}[0-9OIlSB]{4}[A-Z]\b');
final _passportNo = RegExp('[A-Z]$_d{7}$_ndAfter');
final _sexLine = RegExp(r'^sex\s*[:\-]?\s*([MFX])$', caseSensitive: false);
final _amount = RegExp(r'(([Rr][Ss]\.?|INR|inr|₹)\s*)?[0-9OoIlSB](?:[ ,.]*[0-9OoIlSB])*');
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
///
/// [glued] is for labels whose value may start with a letter right after the
/// label when OCR drops the space ("RollNoS028527"). Leave it off for labels
/// that could be the start of a longer word.
RegExp _label(String body, {bool glued = false}) {
  final out = StringBuffer('^');
  var inRange = false; // inside [...], letters are not expanded
  for (var i = 0; i < body.length; i++) {
    final c = body[i];
    final escaped = i > 0 && body[i - 1] == '\\';
    if (!escaped && (c == '[' || c == ']')) inRange = c == '[';
    if (inRange || c == ']') {
      out.write(c);
    } else if (!escaped && c == ' ') {
      out.write(r'\s*'); // some OCR models drop the spaces between words
    } else {
      out.write(!escaped && _looksLike.containsKey(c) ? _looksLike[c] : c);
    }
  }
  if (!glued) out.write('(?![a-z])'); // a digit right after a label is its value
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
            RegExp(r'^(\S{1,2}?)(\s*[A-Za-z]{3,9}\s*)(\S+)$'),
            (m) => '${_digits(m[1]!)}${m[2]}${_digits(m[3]!)}',
          )
        : _digits(s);
  }
  if (identical(pattern, _gpa) || identical(pattern, _passportNo)) {
    return identical(pattern, _passportNo) ? s[0] + _digits(s.substring(1)) : _digits(s);
  }
  if (identical(pattern, _amount)) {
    final prefix = RegExp(r'^((rs\.?|inr|₹)\s*)', caseSensitive: false).firstMatch(s)?.group(0) ?? '';
    // A "." that separates digit groups is a misread "," ("10,00.000"); only
    // a final "." with one or two digits after it is a decimal point.
    final body = _digits(s.substring(prefix.length).replaceAll(' ', ''))
        .replaceAll(RegExp(r'\.(?=\d{3}|\d{2}[,.])'), ',')
        .replaceAll(RegExp(r'[,.]$'), '');
    return prefix + body;
  }
  return s;
}

/// A line that is only a name (letters, spaces, full stops). OCR may have
/// run the words together, so one long word counts too.
String? _nameOnly(String line) =>
    RegExp(r'^[A-Za-z .]{3,}$').hasMatch(line) ? line : null;

String? _semester(String? v) {
  if (v == null) return null;
  const roman = {'I': '1', 'II': '2', 'III': '3', 'IV': '4', 'V': '5', 'VI': '6', 'VII': '7', 'VIII': '8'};
  final t = v.trim().toUpperCase().replaceAll(RegExp('[L1J|]'), 'I');
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
          .replaceFirst(RegExp('^[\\s:\\-.\u2013\u2014]*'), '');
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
      if (identical(pattern, _sexLine)) return m.group(1)!.toUpperCase();
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
