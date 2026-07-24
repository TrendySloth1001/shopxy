// Names intentionally match the backend's SCREAMING_SNAKE wire format so
// `CustomFieldType.fromWire` / `.name` is a no-op round trip.
// ignore_for_file: constant_identifier_names

/// Field-type enum mirrored from the backend.
enum CustomFieldType {
  TEXT,
  LONG_TEXT,
  NUMBER,
  DATE,
  BOOLEAN,
  DROPDOWN;

  static CustomFieldType fromWire(String raw) {
    return CustomFieldType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => CustomFieldType.TEXT,
    );
  }

  String get displayLabel {
    switch (this) {
      case CustomFieldType.TEXT:
        return 'Text';
      case CustomFieldType.LONG_TEXT:
        return 'Long text';
      case CustomFieldType.NUMBER:
        return 'Number';
      case CustomFieldType.DATE:
        return 'Date';
      case CustomFieldType.BOOLEAN:
        return 'Yes / No';
      case CustomFieldType.DROPDOWN:
        return 'Dropdown';
    }
  }
}

/// Optional grouping for [CustomFieldDefinition]s. Lets the user
/// organise per-product data into clusters like "Warranty",
/// "Logistics", "Electronics" rather than a flat list.
class CustomFieldSection {
  const CustomFieldSection({
    required this.id,
    required this.name,
    this.icon,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.fields = const [],
  });

  final String id;
  final String name;
  final String? icon;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CustomFieldDefinition> fields;

  CustomFieldSection copyWith({
    String? name,
    String? icon,
    int? sortOrder,
    bool? isActive,
    List<CustomFieldDefinition>? fields,
  }) {
    return CustomFieldSection(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      fields: fields ?? this.fields,
    );
  }
}

/// Shop-wide definition. One row per field the shop owner has created.
class CustomFieldDefinition {
  const CustomFieldDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.options,
    this.unitSuffix,
    this.icon,
    this.sectionId,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final CustomFieldType type;
  final List<String>? options;
  final String? unitSuffix;
  final String? icon;
  final String? sectionId;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomFieldDefinition copyWith({
    String? name,
    CustomFieldType? type,
    List<String>? options,
    String? unitSuffix,
    String? icon,
    String? sectionId,
    int? sortOrder,
    bool? isActive,
  }) {
    return CustomFieldDefinition(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      options: options ?? this.options,
      unitSuffix: unitSuffix ?? this.unitSuffix,
      icon: icon ?? this.icon,
      sectionId: sectionId ?? this.sectionId,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Tree response from `GET /custom-fields/tree` — sections with their
/// fields embedded, plus the un-sectioned ones in a separate bucket.
class CustomFieldsTree {
  const CustomFieldsTree({
    required this.sections,
    required this.ungrouped,
  });

  final List<CustomFieldSection> sections;
  final List<CustomFieldDefinition> ungrouped;

  bool get isEmpty => sections.isEmpty && ungrouped.isEmpty;
}

/// Predefined template the user can apply in one tap.
class CustomFieldTemplate {
  const CustomFieldTemplate({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
    required this.fieldCount,
  });

  final String id;
  final String label;
  final String icon;
  final String description;
  final int fieldCount;
}

/// One product's value for one definition. `definition` is always
/// included from the backend because the value is meaningless without
/// the type info that tells the UI how to render it.
class ProductCustomFieldValue {
  const ProductCustomFieldValue({
    required this.id,
    required this.productId,
    required this.definitionId,
    required this.definition,
    required this.value,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String productId;
  final String definitionId;
  final CustomFieldDefinition definition;
  final String value;
  final DateTime createdAt;
  final DateTime updatedAt;
}
