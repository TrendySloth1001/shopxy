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
    return {
      'name': name,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (sortOrder != null) 'sortOrder': sortOrder,
    };
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? description,
    String? imageUrl,
    int? sortOrder,
    bool? isActive,
  }) {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (isActive != null) 'isActive': isActive,
    };
  }
}
