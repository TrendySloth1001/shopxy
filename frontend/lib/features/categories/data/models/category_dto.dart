import 'package:shopxy/features/categories/domain/entities/category.dart';

class CategoryDto {
  static Category fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
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
      slug: json['slug'] as String?,
      parentId: json['parentId']?.toString(),
    );
  }

  /// Tree-shape parser — mirrors backend categories.service.getTree.
  /// Each node carries the same flat Category payload plus its already-
  /// resolved children list.
  static CategoryNode treeNodeFromJson(Map<String, dynamic> json) {
    final children = (json['children'] as List<dynamic>? ?? [])
        .map((e) => treeNodeFromJson(e as Map<String, dynamic>))
        .toList();
    return CategoryNode(category: fromJson(json), children: children);
  }

  static Map<String, dynamic> toCreateJson({
    required String name,
    String? description,
    String? imageUrl,
    String? iconName,
    int? sortOrder,
    String? parentId,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'iconName': iconName,
      'sortOrder': sortOrder,
      'parentId': parentId,
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
    Object? parentId = _absent,
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
    // parentId distinguishes "leave alone" (absent), "clear" (explicit null
    // → move to root), and "re-parent" (int). Matches the backend service
    // which uses `data.parentId !== undefined` to decide whether to touch.
    if (!identical(parentId, _absent)) {
      data['parentId'] = parentId;
    }
    return data;
  }
}

const Object _absent = Object();
