import 'package:shopxy/features/categories/domain/entities/category.dart';

class CategoryDto {
  static Category fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
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
    int? sortOrder,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? description,
    String? imageUrl,
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
    return data;
  }
}
