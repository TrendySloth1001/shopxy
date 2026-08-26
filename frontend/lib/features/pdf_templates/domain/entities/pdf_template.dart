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
