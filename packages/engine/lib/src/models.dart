/// Document types in scope (see docs/research/text/final-research-plan.txt).
/// `passport` is only used by the consistency audit.
enum DocType { aadhaar, pan, marksheet, insurance, certificate, passport }

/// What OCR / text extraction produced for one document.
///
/// Field keys are lower_snake_case: `name`, `dob`, `gender`, `father_name`,
/// `id_number`, `expiry_date`, `cgpa`, ... The same shape is written by the
/// dataset generator as ground truth (docs/contracts/fields.md).
class ExtractedDoc {
  const ExtractedDoc({
    required this.id,
    required this.type,
    required this.fields,
    this.text = '',
  });

  final String id;
  final DocType type;
  final Map<String, String> fields;

  /// Full text of the document, used to notice changes outside tracked fields.
  final String text;

  factory ExtractedDoc.fromJson(Map<String, dynamic> json) => ExtractedDoc(
    id: json['id'] as String,
    type: DocType.values.byName(json['doc_type'] as String),
    fields: Map<String, String>.from(json['fields'] as Map),
    text: (json['text'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'doc_type': type.name,
    'fields': fields,
    'text': text,
  };
}
