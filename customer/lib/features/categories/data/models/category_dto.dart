import 'package:shopxy_customer/shared/domain/entities/category.dart';

class CategoryDto {
  static Category fromJson(Map<String, dynamic> json) => Category(
        id: json['id'].toString(),
        slug: json['slug'] as String,
        name: json['name'] as String,
        imageUrl: json['imageUrl'] as String?,
        iconName: json['iconName'] as String?,
        parentId: json['parentId']?.toString(),
      );

  static CategoryNode treeNodeFromJson(Map<String, dynamic> json) {
    final children = (json['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(treeNodeFromJson)
        .toList();
    return CategoryNode(category: fromJson(json), children: children);
  }
}
