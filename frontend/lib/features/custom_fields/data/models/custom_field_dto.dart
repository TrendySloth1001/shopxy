import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';

class CustomFieldDefinitionDto {
  static CustomFieldDefinition fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    return CustomFieldDefinition(
      id: json['id'] as int,
      name: json['name'] as String,
      type: CustomFieldType.fromWire(json['type'] as String),
      options: rawOptions is List
          ? rawOptions.map((e) => e.toString()).toList()
          : null,
      unitSuffix: json['unitSuffix'] as String?,
      icon: json['icon'] as String?,
      sectionId: json['sectionId'] as int?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static Map<String, dynamic> toCreateJson({
    required String name,
    required CustomFieldType type,
    List<String>? options,
    String? unitSuffix,
    String? icon,
    int? sectionId,
    int? sortOrder,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'type': type.name,
      'options': options,
      'unitSuffix': unitSuffix,
      'icon': icon,
      'sectionId': sectionId,
      'sortOrder': sortOrder,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    CustomFieldType? type,
    List<String>? options,
    String? unitSuffix,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'type': type?.name,
      'options': options,
      'unitSuffix': unitSuffix,
      'icon': icon,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }

  /// Section assignment is split off because `null` is a meaningful
  /// value here ("remove from section, render at the top") — bundling
  /// it into [toUpdateJson] would conflict with our null-strips logic.
  static Map<String, dynamic> toAssignSectionJson({required int? sectionId}) {
    return {'sectionId': sectionId};
  }
}

class CustomFieldSectionDto {
  static CustomFieldSection fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'];
    return CustomFieldSection(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      fields: fieldsRaw is List
          ? fieldsRaw
              .map((e) =>
                  CustomFieldDefinitionDto.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }

  static Map<String, dynamic> toCreateJson({
    required String name,
    String? icon,
    int? sortOrder,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'icon': icon,
      'sortOrder': sortOrder,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'icon': icon,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }
}

class CustomFieldsTreeDto {
  static CustomFieldsTree fromJson(Map<String, dynamic> json) {
    final sections = json['sections'] as List? ?? const [];
    final ungrouped = json['ungrouped'] as List? ?? const [];
    return CustomFieldsTree(
      sections: sections
          .map((e) => CustomFieldSectionDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      ungrouped: ungrouped
          .map((e) =>
              CustomFieldDefinitionDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomFieldTemplateDto {
  static CustomFieldTemplate fromJson(Map<String, dynamic> json) {
    return CustomFieldTemplate(
      id: json['id'] as String,
      label: json['label'] as String,
      icon: json['icon'] as String? ?? 'inventory_2',
      description: json['description'] as String? ?? '',
      fieldCount: json['fieldCount'] as int? ?? 0,
    );
  }
}

class ProductCustomFieldValueDto {
  static ProductCustomFieldValue fromJson(Map<String, dynamic> json) {
    return ProductCustomFieldValue(
      id: json['id'] as int,
      productId: json['productId'] as int,
      definitionId: json['definitionId'] as int,
      definition: CustomFieldDefinitionDto.fromJson(
        json['definition'] as Map<String, dynamic>,
      ),
      value: json['value'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
