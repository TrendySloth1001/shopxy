class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    this.imageUrl,
    this.iconName,
    this.parentId,
  });

  final String id;
  final String slug;
  final String name;
  final String? imageUrl;
  final String? iconName;
  final String? parentId;
}

class CategoryNode {
  const CategoryNode({required this.category, required this.children});
  final Category category;
  final List<CategoryNode> children;
}
