import 'package:shopxy/features/categories/domain/entities/category.dart';

class CategoryDto {
  static Category fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      iconName: json['iconName'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      productCount: json['_count'] != null
          ? (json['_count']['products'] as int?)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static Map<String, dynamic> toCreateJson({
    required String name,
    String? description,
    String? imageUrl,
    String? iconName,
    int? sortOrder,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'iconName': iconName,
      'sortOrder': sortOrder,
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }

  /// Update payload — distinguishes "field unchanged" (omit the key)
  /// from "field cleared" (caller passes the string `null` sentinel via
  /// the dedicated [clearIcon] flag). Keeps the icon picker honest when
  /// the user picks "No icon" after previously selecting one.
  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? description,
    String? imageUrl,
    String? iconName,
    bool clearIcon = false,
    int? sortOrder,
    bool? isActive,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
    data.removeWhere((_, value) => value == null);
    if (clearIcon) {
      data['iconName'] = null;
    } else if (iconName != null) {
      data['iconName'] = iconName;
    }
    return data;
  }
}
