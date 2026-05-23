/// Single product as shown in the customer-facing catalog.
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.sellingPrice,
    required this.mrp,
    required this.taxPercent,
    required this.stockQuantity,
    required this.imageUrl,
    this.description,
    this.hsnCode,
    this.categoryId,
    this.categoryName,
    this.categoryIconName,
  });

  final int id;
  final String name;
  final String sku;
  final String unit;
  final double sellingPrice;
  final double mrp;
  final double taxPercent;
  final double stockQuantity;
  final String? imageUrl;
  final String? description;
  final String? hsnCode;
  final int? categoryId;
  final String? categoryName;
  final String? categoryIconName;

  bool get inStock => stockQuantity > 0;
  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;

  /// Tolerant of Prisma's `Decimal → JSON string` quirk.
  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory CatalogProduct.fromJson(Map<String, dynamic> j) {
    final images = j['images'] as List<dynamic>?;
    final firstImage = images != null && images.isNotEmpty
        ? (images.first as Map<String, dynamic>)['url'] as String?
        : null;
    final category = j['category'] as Map<String, dynamic>?;

    return CatalogProduct(
      id: j['id'] as int,
      name: j['name'] as String,
      sku: j['sku'] as String,
      unit: j['unit'] as String? ?? 'PCS',
      sellingPrice: _d(j['sellingPrice']),
      mrp: _d(j['mrp']),
      taxPercent: _d(j['taxPercent']),
      stockQuantity: _d(j['stockQuantity']),
      imageUrl: firstImage,
      description: j['description'] as String?,
      hsnCode: j['hsnCode'] as String?,
      categoryId: j['categoryId'] as int?,
      categoryName: category?['name'] as String?,
      categoryIconName: category?['iconName'] as String?,
    );
  }
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.iconName,
    this.productCount = 0,
  });
  final int id;
  final String name;
  final String? imageUrl;
  final String? iconName;
  final int productCount;

  factory CatalogCategory.fromJson(Map<String, dynamic> j) {
    return CatalogCategory(
      id: j['id'] as int,
      name: j['name'] as String,
      imageUrl: j['imageUrl'] as String?,
      iconName: j['iconName'] as String?,
      productCount: ((j['_count'] as Map?)?['products'] as int?) ?? 0,
    );
  }
}
