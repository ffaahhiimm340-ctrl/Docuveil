import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:docuveil_engine/docuveil_engine.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfrx/pdfrx.dart';

import 'ocr_service.dart';
import 'reminders.dart';
import 'safety_center.dart';
import 'vault.dart';

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

  /// Safety checks run on the picked file.
  FileReport? safety;

  /// The text came from OCR, so it is more likely to contain mistakes.
  bool fromScan = false;
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
    final draft = await readBytes(type, f.name, ext ?? '', bytes, OcrEngine.forPlatform());
    draft.safety = SafetyLog.check(f.name, f.path, bytes, draft.text);
    current.value = draft;
    return draft;
  }

  /// Read a file's bytes into a draft: its text layer when it has one, else
  /// OCR. A file that cannot be read still gives a draft, for typing by hand.
  static Future<IntakeDraft> readBytes(
    DocType type,
    String name,
    String ext,
    Uint8List bytes,
    OcrEngine? ocr,
  ) async {
    Future<IntakeDraft> viaOcr(Future<String> Function(OcrEngine) read) async {
      if (ocr == null) {
        return _problem(
          draftFromText(type, name, bytes, ''),
          'This device cannot read scans yet. Please type the details.',
        );
      }
      try {
        final text = await read(ocr);
        if (text.trim().isEmpty) {
          return _problem(
            draftFromText(type, name, bytes, ''),
            'We could not find any text in this file. Please type the details.',
          );
        }
        final d = draftFromText(type, name, bytes, text);
        d.fromScan = true;
        return d;
      } catch (e) {
        debugPrint('OCR failed: $e');
        return _problem(
          draftFromText(type, name, bytes, ''),
          'We could not read this scan. Please type the details.',
        );
      }
    }

    if (ext == 'txt') {
      return draftFromText(type, name, bytes, utf8.decode(bytes, allowMalformed: true));
    }
    if (ext == 'pdf') {
      final text = await pdfText(bytes);
      if (text.trim().isNotEmpty) return draftFromText(type, name, bytes, text);
      return viaOcr((e) => ocrPdf(e, bytes));
    }
    return viaOcr((e) => ocrBytes(e, bytes, ext));
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
      fileName: d.fileName,
    );
    await Vault.add(doc);
    await Reminders.reschedule();
    return doc;
  }
}
