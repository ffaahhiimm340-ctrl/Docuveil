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

  test('a missing label gives no field rather than a wrong one', () {
    final f = extractFields(DocType.pan, 'INCOME TAX DEPARTMENT\nSignature');
    expect(f.containsKey('name'), isFalse);
    expect(f.containsKey('dob'), isFalse);
  });
}
