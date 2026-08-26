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
    this.shopId,
    this.shopName,
    this.shopSlug,
    this.shopGstRegistered = false,
  });

  final String id;
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
  final String? categoryId;
  final String? categoryName;
  final String? categoryIconName;
  final String? shopId;
  final String? shopName;
  final String? shopSlug;

  final bool shopGstRegistered;

  bool get inStock => stockQuantity > 0;
  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;

  CatalogProduct copyWithPrice(double newSellingPrice) => CatalogProduct(
        id: id,
        name: name,
        sku: sku,
        unit: unit,
        sellingPrice: newSellingPrice,
        mrp: mrp,
        taxPercent: taxPercent,
        stockQuantity: stockQuantity,
        imageUrl: imageUrl,
        description: description,
        hsnCode: hsnCode,
        categoryId: categoryId,
        categoryName: categoryName,
        categoryIconName: categoryIconName,
        shopId: shopId,
        shopName: shopName,
        shopSlug: shopSlug,
        shopGstRegistered: shopGstRegistered,
      );

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
    final shop = j['shop'] as Map<String, dynamic>?;

    return CatalogProduct(
      id: j['id'].toString(),
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
      categoryId: j['categoryId']?.toString(),
      categoryName: category?['name'] as String?,
      categoryIconName: category?['iconName'] as String?,
      shopId: (shop?['id']?.toString()) ?? (j['shopId']?.toString()),
      shopName: shop?['name'] as String?,
      shopGstRegistered: shop?['gstRegistered'] == true,
      shopSlug: shop?['slug'] as String?,
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
  final String id;
  final String name;
  final String? imageUrl;
  final String? iconName;
  final int productCount;

  factory CatalogCategory.fromJson(Map<String, dynamic> j) {
    return CatalogCategory(
      id: j['id'].toString(),
      name: j['name'] as String,
      imageUrl: j['imageUrl'] as String?,
      iconName: j['iconName'] as String?,
      productCount: ((j['_count'] as Map?)?['products'] as int?) ?? 0,
    );
  }
}
