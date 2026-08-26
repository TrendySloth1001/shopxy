class AdminCollectionSummary {
  const AdminCollectionSummary({
    required this.id,
    required this.slug,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.coverImageUrl,
    this.bgColor,
    required this.isPublished,
    required this.sortOrder,
    required this.itemCount,
  });

  final String id;
  final String slug;
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final String? coverImageUrl;
  final String? bgColor;
  final bool isPublished;
  final int sortOrder;
  final int itemCount;

  factory AdminCollectionSummary.fromJson(Map<String, dynamic> j) {
    final count = j['_count'] is Map
        ? (j['_count'] as Map)['items'] as int? ?? 0
        : 0;
    return AdminCollectionSummary(
      id: j['id'].toString(),
      slug: j['slug'] as String,
      title: j['title'] as String,
      eyebrow: j['eyebrow'] as String?,
      subtitle: j['subtitle'] as String?,
      coverImageUrl: j['coverImageUrl'] as String?,
      bgColor: j['bgColor'] as String?,
      isPublished: j['isPublished'] as bool? ?? false,
      sortOrder: j['sortOrder'] as int? ?? 0,
      itemCount: count,
    );
  }
}

class AdminCollection {
  const AdminCollection({
    required this.id,
    required this.slug,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.ctaText,
    this.ctaTarget,
    this.coverImageUrl,
    this.bgColor,
    required this.isPublished,
    required this.sortOrder,
    required this.items,
  });

  final String id;
  final String slug;
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final String? ctaText;
  final String? ctaTarget;
  final String? coverImageUrl;
  final String? bgColor;
  final bool isPublished;
  final int sortOrder;
  final List<AdminCollectionItem> items;

  factory AdminCollection.fromJson(Map<String, dynamic> j) => AdminCollection(
        id: j['id'].toString(),
        slug: j['slug'] as String,
        title: j['title'] as String,
        eyebrow: j['eyebrow'] as String?,
        subtitle: j['subtitle'] as String?,
        ctaText: j['ctaText'] as String?,
        ctaTarget: j['ctaTarget'] as String?,
        coverImageUrl: j['coverImageUrl'] as String?,
        bgColor: j['bgColor'] as String?,
        isPublished: j['isPublished'] as bool? ?? false,
        sortOrder: j['sortOrder'] as int? ?? 0,
        items: ((j['items'] as List<dynamic>?) ?? const [])
            .map((e) => AdminCollectionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AdminCollectionItem {
  const AdminCollectionItem({
    required this.id,
    required this.position,
    required this.product,
  });

  final String id;
  final int position;
  final AdminCollectionProduct product;

  factory AdminCollectionItem.fromJson(Map<String, dynamic> j) =>
      AdminCollectionItem(
        id: j['id']?.toString() ?? '',
        position: j['position'] as int? ?? 0,
        product:
            AdminCollectionProduct.fromJson(j['product'] as Map<String, dynamic>),
      );
}

class AdminCollectionProduct {
  const AdminCollectionProduct({
    required this.id,
    required this.name,
    required this.sku,
    this.imageUrl,
    this.shopName,
  });

  final String id;
  final String name;
  final String sku;
  final String? imageUrl;
  final String? shopName;

  factory AdminCollectionProduct.fromJson(Map<String, dynamic> j) {
    final imgs = (j['images'] as List<dynamic>?) ?? const [];
    final firstImg = imgs.isEmpty ? null : (imgs.first as Map)['url'] as String?;
    final shop = j['shop'] as Map<String, dynamic>?;
    return AdminCollectionProduct(
      id: j['id'].toString(),
      name: j['name'] as String,
      sku: j['sku'] as String,
      imageUrl: firstImg,
      shopName: shop?['name'] as String?,
    );
  }
}
