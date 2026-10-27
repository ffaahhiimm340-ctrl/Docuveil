import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';
import 'normalize.dart';

/// What one device sends to the relay for one document. Every string is an
/// HMAC under the owner's key, so the server cannot confirm a known file or
/// learn field names or values. It still sees timing and message counts.
class FingerprintSet {
  const FingerprintSet(this.docTag, this.fields);

  /// Opaque document id.
  final String docTag;

  /// field tag -> value tag.
  final Map<String, String> fields;

  factory FingerprintSet.fromJson(Map<String, dynamic> j) => FingerprintSet(
    j['doc'] as String,
    Map<String, String>.from(j['fields'] as Map),
  );

  Map<String, dynamic> toJson() => {'doc': docTag, 'fields': fields};
}

String _hmac(List<int> key, String domain, String data) => Hmac(
  sha256,
  key,
).convert(utf8.encode('$domain\u0000$data')).toString();

/// Tag for a field name. Devices keep the tag -> name table locally.
String fieldTag(List<int> key, String field) => _hmac(key, 'field', field);

/// Build the keyed fingerprint of a document. The value tag also covers the
/// field name and doc id, so equal values in different fields or documents
/// give different tags.
FingerprintSet fingerprint(List<int> key, ExtractedDoc doc) {
  final docTag = _hmac(key, 'doc', doc.id);
  return FingerprintSet(docTag, {
    for (final e in doc.fields.entries)
      fieldTag(key, e.key): _hmac(
        key,
        'value',
        '${doc.id}\u0000${e.key}\u0000${normalizeField(e.key, e.value)}',
      ),
  });
}

/// Field tags whose value differs, or that exist on only one side.
Set<String> changedFieldTags(FingerprintSet a, FingerprintSet b) => {
  for (final t in {...a.fields.keys, ...b.fields.keys})
    if (a.fields[t] != b.fields[t]) t,
};

/// Turn changed tags back into field names using the local table.
List<String> namesForTags(
  List<int> key,
  Iterable<String> tags,
  Iterable<String> knownFields,
) {
  final table = {for (final f in knownFields) fieldTag(key, f): f};
  return [for (final t in tags) table[t] ?? 'unknown field'];
}
