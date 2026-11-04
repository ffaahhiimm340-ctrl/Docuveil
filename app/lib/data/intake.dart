import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import 'vault.dart';

/// The fields a paper of each type should have; anything the extractor did
/// not find is shown empty for the owner to type.
const expectedFields = {
  DocType.aadhaar: ['name', 'dob', 'gender', 'father_name', 'id_number'],
  DocType.pan: ['name', 'dob', 'father_name', 'id_number'],
  DocType.marksheet: ['name', 'dob', 'seat_number', 'semester', 'cgpa'],
  DocType.insurance: ['name', 'policy_number', 'sum_assured', 'expiry_date', 'nominee'],
  DocType.certificate: ['name', 'degree', 'year'],
  DocType.passport: ['name', 'dob', 'gender', 'father_name', 'id_number', 'expiry_date'],
};

/// A paper read from a file, before the owner confirms it as the original.
class IntakeDraft {
  IntakeDraft({
    required this.type,
    required this.fileName,
    required this.sha256,
    required this.text,
    required this.fields,
    required this.unread,
    this.problem,
  });

  final DocType type;
  final String fileName;
  final String sha256;
  final String text;

  /// Field key -> value; the owner may edit these on the check screen.
  final Map<String, String> fields;

  /// Expected fields the extractor could not read.
  final Set<String> unread;

  /// Set when the file could not be read at all (e.g. a photo, for now).
  final String? problem;
}

/// Build a draft from a file's bytes and its text. Pure, so it is testable.
IntakeDraft draftFromText(DocType type, String fileName, Uint8List bytes, String text) {
  final found = extractFields(type, text);
  final keys = expectedFields[type]!;
  return IntakeDraft(
    type: type,
    fileName: fileName,
    sha256: sha256.convert(bytes).toString(),
    text: text,
    fields: {for (final k in keys) k: found[k] ?? '', ...found},
    unread: {for (final k in keys) if (!found.containsKey(k)) k},
  );
}

/// Text of a PDF's text layer, page after page. Empty for a scanned PDF
/// (pictures only), which needs OCR.
Future<String> pdfText(Uint8List bytes) async {
  final doc = await PdfDocument.openData(bytes);
  try {
    final pages = <String>[];
    for (final p in doc.pages) {
      pages.add((await p.loadText())?.fullText ?? '');
    }
    return pages.join('\n');
  } finally {
    await doc.dispose();
  }
}

class Intake {
  Intake._();

  /// The paper being added, shared by the three Add screens.
  static final ValueNotifier<IntakeDraft?> current = ValueNotifier(null);

  /// Let the owner pick a PDF or text file and read it. Returns null if
  /// they cancelled.
  static Future<IntakeDraft?> pickAndRead(DocType type) async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'jpg', 'jpeg', 'png'],
    );
    if (f == null) return null;
    final bytes = await f.readAsBytes();
    final ext = f.extension?.toLowerCase();
    IntakeDraft draft;
    if (ext == 'pdf' || ext == 'txt') {
      final text = ext == 'pdf' ? await pdfText(bytes) : utf8.decode(bytes, allowMalformed: true);
      draft = draftFromText(type, f.name, bytes, text);
      if (text.trim().isEmpty) {
        draft = _problem(draft, 'This PDF has no text layer (it is a scan). Reading scans is coming; please type the details.');
      }
    } else {
      draft = _problem(
        draftFromText(type, f.name, bytes, ''),
        'Reading photos needs on-device OCR, which is coming. Please type the details.',
      );
    }
    current.value = draft;
    return draft;
  }

  static IntakeDraft _problem(IntakeDraft d, String why) => IntakeDraft(
    type: d.type,
    fileName: d.fileName,
    sha256: d.sha256,
    text: d.text,
    fields: d.fields,
    unread: d.unread,
    problem: why,
  );

  /// Save the confirmed draft as the original of a new paper.
  static Future<VaultDoc> save(IntakeDraft d, {String location = 'This device'}) async {
    final doc = VaultDoc(
      ExtractedDoc(
        id: '${d.type.name}-${d.sha256.substring(0, 12)}',
        type: d.type,
        fields: {
          for (final e in d.fields.entries)
            if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
        },
        text: d.text,
      ),
      location,
    );
    await Vault.add(doc);
    return doc;
  }
}
