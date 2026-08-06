/// One of the ~7 preset PDF look-and-feels a shop's invoices/quotations/
/// challans can render with — metadata only (name/description). The
/// thumbnail image is a bundled asset at `assets/template_thumbnails/<id>.png`,
/// not fetched — see `assets/template_thumbnails/` and `pubspec.yaml`.
class PdfTemplate {
  const PdfTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
  });

  final String id;
  final String name;
  final String description;
  final int order;

  factory PdfTemplate.fromJson(Map<String, dynamic> json) => PdfTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String,
    order: (json['order'] as num?)?.toInt() ?? 0,
  );
}
