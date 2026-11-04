import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Aadhaar: unlabelled name above DOB, D/O father, grouped number', () {
    final f = extractFields(DocType.aadhaar, '''
GOVERNMENT OF INDIA
Asha Rajesh Verma
DOB: 04/07/2001
FEMALE
1234 5678 9012
D/O: Rajesh Verma, 12 Sample Nagar, Pune''');
    expect(f, {
      'name': 'Asha Rajesh Verma',
      'dob': '04/07/2001',
      'gender': 'FEMALE',
      'id_number': '1234 5678 9012',
      'father_name': 'Rajesh Verma',
    });
  });

  test('PAN: labels on the line above, father not mistaken for name', () {
    final f = extractFields(DocType.pan, '''
INCOME TAX DEPARTMENT
Permanent Account Number Card
ABCPV1234F
Name
ASHA RAJESH VERMA
Father's Name
RAJESH VERMA
Date of Birth
04/07/2001''');
    expect(f['name'], 'ASHA RAJESH VERMA');
    expect(f['father_name'], 'RAJESH VERMA');
    expect(f['id_number'], 'ABCPV1234F');
    expect(f['dob'], '04/07/2001');
  });

  test('passport: surname and given names are joined', () {
    final f = extractFields(DocType.passport, '''
Surname
VERMA
Given Name(s)
ASHA RAJESH
Sex : F
Passport No. : P1234567''');
    expect(f['name'], 'ASHA RAJESH VERMA');
    expect(f['gender'], 'F');
    expect(f['id_number'], 'P1234567');
  });

  test('marksheet: roman semester and OCR-damaged labels and numbers', () {
    final f = extractFields(DocType.marksheet, '''
SYNTHETIC UNIVERSITY OF PUNE
Narne of the Student : Asha Verma
Seat No. : S482913
Scmester : II
Date of Birth : O4/07/2OO1
CGPA : B.74''');
    expect(f['name'], 'Asha Verma');
    expect(f['semester'], '2');
    expect(f['dob'], '04/07/2001');
    expect(f['cgpa'], '8.74');
    expect(f['seat_number'], 'S482913');
  });

  test('insurance: Indian amount with Rs. prefix', () {
    final f = extractFields(DocType.insurance, '''
Sample General Insurance
Policy No. : POL48291355
Sum Insured : Rs. 5,00,000
Valid Till : 12/03/2027''');
    expect(f['policy_number'], 'POL48291355');
    expect(normalizeField('sum_assured', f['sum_assured']!), '500000');
    expect(f['expiry_date'], '12/03/2027');
  });

  test('OCR that drops spaces: values glued to labels are still found', () {
    final f = extractFields(DocType.passport, '''
Surname
VERMA
GivenName(s)
ASHARAJESH
SexF
DateofBirth17Oct1993
PassportNo.W6669725''');
    expect(f['gender'], 'F');
    expect(normalizeField('dob', f['dob']!), '1993-10-17');
    expect(f['id_number'], 'W6669725');
    expect(normalizeField('name', f['name']!), normalizeField('name', 'Asha Rajesh Verma'));
  });

  test('an edited number the extractor did not read is never harmless', () {
    ExtractedDoc d(String text) =>
        ExtractedDoc(id: 'x', type: DocType.passport, fields: const {}, text: text);
    final r = compareVersions(
      DocSnapshot('a', d('Surname VERMA Date of Birth 17 Oct 1993 Result PASS')),
      DocSnapshot('b', d('Surname VERMA Date of Birth 17 Oct 1996 Result PASS')),
    );
    expect(r.verdict, Verdict.review);
    expect(r.harmlessNotes, contains('a number elsewhere on the page differs'));
  });

  test('values starting with a letter glued to the label are found', () {
    final m = extractFields(DocType.marksheet, 'NameAman Reddy\nRollNoS028527\nSemester2');
    expect(m['name'], 'Aman Reddy');
    expect(m['seat_number'], 'S028527');
    expect(m['semester'], '2');
    final i = extractFields(DocType.insurance, 'X\nPo1icy No.POL35570283\nSumInsuredRs.10,00.000');
    expect(i['policy_number'], 'POL35570283');
    expect(normalizeField('sum_assured', i['sum_assured']!), '1000000');
  });

  test('as Windows OCR prints things: split amounts, odd dashes, misread numerals', () {
    final i = extractFields(DocType.insurance, 'X\nSum Assured Rs. 1, 000, 000');
    expect(normalizeField('sum_assured', i['sum_assured']!), '1000000');
    final p = extractFields(DocType.pan, 'Date of Birth\n4\uFFFD6\u20131996');
    expect(normalizeField('dob', p['dob']!), '1996-06-04');
    final m = extractFields(DocType.marksheet, 'Semester : JJ\nName : A B');
    expect(m['semester'], '2');
    final s = extractFields(DocType.passport, 'Passport No. Fli56527');
    expect(normalizeField('id_number', s['id_number']!), normalizeField('id_number', 'F1156527'));
  });

  test('the letter s of a garbled Rs is not taken as an amount', () {
    final i = extractFields(DocType.insurance, 'X\nSum Assured : Rs');
    expect(i.containsKey('sum_assured'), isFalse);
  });

  test('labels as Windows OCR misreads or spaces them', () {
    final p = extractFields(DocType.passport, 'Surname\nNAIR\nGiven Name (s)\nKAVYA PRASAD');
    expect(p['name'], 'KAVYA PRASAD NAIR');
    final m = extractFields(DocType.marksheet, 'Date ofBinh - 27/01/1997');
    expect(normalizeField('dob', m['dob']!), '1997-01-27');
  });

  test('look-alike letters in names go to review, a different letter does not', () {
    Verdict v(String x, String y) => compareVersions(
      DocSnapshot('a', ExtractedDoc(id: 'n', type: DocType.pan, fields: {'name': x})),
      DocSnapshot('b', ExtractedDoc(id: 'n', type: DocType.pan, fields: {'name': y})),
    ).verdict;
    for (final (x, y) in [('Asha Iyer', 'Asha Jyer'), ('Asha lyer', 'Asha tyer'), ('Asha lyer', 'Asha (yer')]) {
      expect(v(x, y), Verdict.review, reason: '$x / $y');
    }
    expect(v('Asha Iyer', 'Asha Oyer'), Verdict.tampered);
    expect(v('Asha Verma', 'Asha Sharma'), Verdict.tampered);
  });

  test('a value the owner typed in, unread on a later scan, asks for a look', () {
    final r = compareVersions(
      DocSnapshot('a', ExtractedDoc(id: 'i', type: DocType.insurance, fields: const {'sum_assured': '500000'})),
      DocSnapshot('b', ExtractedDoc(id: 'i', type: DocType.insurance, fields: const {})),
    );
    expect(r.verdict, Verdict.review);
    expect(r.summary(), contains('could not be read'));
  });

  test('a real decimal in an amount is kept', () {
    final i = extractFields(DocType.insurance, 'X\nSum Insured : 5000.50');
    expect(normalizeField('sum_assured', i['sum_assured']!), '5000.5');
  });

  test('certificate: prose and labelled layouts', () {
    final a = extractFields(DocType.certificate, '''
FICTIONAL INSTITUTE OF TECHNOLOGY
DEGREE CERTIFICATE
This is to certify that
Asha Rajesh Verma
has been awarded the degree of
B.Sc. Computer Science
in the year 2023''');
    expect(a, {
      'name': 'Asha Rajesh Verma',
      'degree': 'B.Sc. Computer Science',
      'year': '2023',
    });
    final b = extractFields(DocType.certificate, 'X\nName : Asha Verma\nDegree : M.C.A.\nYear : 2019');
    expect(b, {'name': 'Asha Verma', 'degree': 'M.C.A.', 'year': '2019'});
  });

  test('a missing label gives no field rather than a wrong one', () {
    final f = extractFields(DocType.pan, 'INCOME TAX DEPARTMENT\nSignature');
    expect(f.containsKey('name'), isFalse);
    expect(f.containsKey('dob'), isFalse);
  });
}
