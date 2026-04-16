class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.sortOrder,
    required this.isActive,
    this.productCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;
  final int? productCount;
  final DateTime createdAt;
  final DateTime updatedAt;
}
