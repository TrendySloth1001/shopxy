class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.iconName,
    required this.sortOrder,
    required this.isActive,
    this.productCount,
    required this.createdAt,
    required this.updatedAt,
    this.slug,
    this.parentId,
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? iconName;
  final int sortOrder;
  final bool isActive;
  final int? productCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? slug;
  final String? parentId;
}

/// Same Category fields plus child categories — what GET /categories/tree
/// returns. Kept separate so non-tree call-sites stay leaner.
class CategoryNode {
  const CategoryNode({required this.category, required this.children});
  final Category category;
  final List<CategoryNode> children;
}

