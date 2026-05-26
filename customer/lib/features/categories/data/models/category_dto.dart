import 'package:shopxy_customer/shared/domain/entities/category.dart';

class CategoryDto {
  static Category fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        slug: json['slug'] as String,
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String?,
        iconName: json['iconName'] as String?,
        parentId: json['parentId'] as int?,
      );

  static CategoryNode treeNodeFromJson(Map<String, dynamic> json) {
    final children = (json['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(treeNodeFromJson)
        .toList();
    return CategoryNode(category: fromJson(json), children: children);
  }
}
