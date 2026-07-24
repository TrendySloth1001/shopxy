/// Single canonical category row. The customer app only reads these —
/// the taxonomy is seeded server-side from a fixed manifest so the
/// shape is stable across releases.
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

/// Tree shape returned by `GET /categories/tree`. Each node carries
/// its [Category] plus its already-resolved children — used by the
/// categories grid + subcategory drill-down so we don't make N+1
/// trips to render a parent → children list.
class CategoryNode {
  const CategoryNode({required this.category, required this.children});
  final Category category;
  final List<CategoryNode> children;
}
