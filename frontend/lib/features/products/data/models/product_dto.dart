import 'package:shopxy/features/categories/data/models/category_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductDto {
  static ProductImage imageFromJson(Map<String, dynamic> json) => ProductImage(
        id: json['id'].toString(),
        productId: json['productId'].toString(),
        url: json['url'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
  static ProductImage _imageFromJson(Map<String, dynamic> json) =>
      imageFromJson(json);

  static Product fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'] as List<dynamic>?;
    return Product(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      sku: json['sku'] as String,
      barcode: json['barcode'] as String?,
      hsnCode: json['hsnCode'] as String?,
      brand: json['brand'] as String?,
      mrp: _toDouble(json['mrp']),
      sellingPrice: _toDouble(json['sellingPrice']),
      purchasePrice: _toDouble(json['purchasePrice']),
      taxPercent: _toDouble(json['taxPercent']),
      // Absent on older backends — default to MANUAL, which is what an
      // un-stamped rate always was.
      taxSource: json['taxSource'] as String? ?? 'MANUAL',
      pricingMode: json['pricingMode'] as String? ?? 'TAX_EXCLUSIVE',
      stockQuantity: _toDouble(json['stockQuantity']),
      lowStockThreshold: _toDouble(json['lowStockThreshold']),
      unit: json['unit'] as String? ?? 'PCS',
      categoryId: json['categoryId']?.toString(),
      category: json['category'] != null
          ? CategoryDto.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      images: imagesJson?.map((e) => _imageFromJson(e as Map<String, dynamic>)).toList() ?? [],
      lastStockInAt: _parseDate(json['lastStockInAt']),
      lastStockOutAt: _parseDate(json['lastStockOutAt']),
      lastVendorId: (json['lastVendor'] as Map<String, dynamic>?)?['id']?.toString(),
      lastVendorName:
          (json['lastVendor'] as Map<String, dynamic>?)?['name'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
      ratingAvg: json['ratingAvg'] == null ? null : _toDouble(json['ratingAvg']),
      ratingCount: json['ratingCount'] as int? ?? 0,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      highlights:
          (json['highlights'] as List<dynamic>?)?.cast<String>() ?? const [],
      specs: (json['specs'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SpecGroup.fromJson)
              .toList() ??
          const [],
      offers: (json['offers'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ProductOffer.fromJson)
              .toList() ??
          const [],
      totalSold: json['totalSold'] as int? ?? 0,
      soldLast30d: json['soldLast30d'] as int? ?? 0,
      systemTags:
          (json['systemTags'] as List<dynamic>?)?.cast<String>() ?? const [],
      contentBlocks: (json['contentBlocks'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ContentBlock.fromJson)
              .toList() ??
          const [],
      variantAxes: (json['variantAxes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(VariantAxis.fromJson)
              .toList() ??
          const [],
      variants: (json['variants'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ProductVariant.fromJson)
              .toList() ??
          const [],
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, dynamic> toCreateJson({
    required String name,
    String? description,
    required String sku,
    String? barcode,
    String? hsnCode,
    String? brand,
    List<String>? imageUrls,
    required double mrp,
    required double sellingPrice,
    required double purchasePrice,
    double? taxPercent,
    String? pricingMode,
    double? stockQuantity,
    double? lowStockThreshold,
    String? unit,
    String? categoryId,
    List<String>? tags,
    List<String>? highlights,
    List<SpecGroup>? specs,
    List<ProductOffer>? offers,
    List<ContentBlock>? contentBlocks,
    List<VariantAxis>? variantAxes,
    List<ProductVariant>? variants,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': (description != null && description.isNotEmpty) ? description : null,
      'sku': sku,
      'barcode': (barcode != null && barcode.isNotEmpty) ? barcode : null,
      'hsnCode': (hsnCode != null && hsnCode.isNotEmpty) ? hsnCode : null,
      'brand': (brand != null && brand.isNotEmpty) ? brand : null,
      'imageUrls': (imageUrls != null && imageUrls.isNotEmpty) ? imageUrls : null,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      'taxPercent': taxPercent,
      'pricingMode': pricingMode,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'categoryId': categoryId,
      'tags': tags,
      'highlights': highlights,
      'specs': specs?.map(_specToJson).toList(),
      'offers': offers?.map((o) => o.toJson()).toList(),
      'contentBlocks': contentBlocks?.map((b) => b.toJson()).toList(),
      'variantAxes': variantAxes?.map((a) => a.toJson()).toList(),
      'variants': variants?.map((v) => v.toJson()).toList(),
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? description,
    String? sku,
    String? barcode,
    String? hsnCode,
    String? brand,
    double? mrp,
    double? sellingPrice,
    double? purchasePrice,
    double? taxPercent,
    String? pricingMode,
    double? lowStockThreshold,
    String? unit,
    String? categoryId,
    bool? isActive,
    bool? isPublished,
    List<String>? tags,
    List<String>? highlights,
    List<SpecGroup>? specs,
    List<ProductOffer>? offers,
    List<ContentBlock>? contentBlocks,
    List<VariantAxis>? variantAxes,
    List<ProductVariant>? variants,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'sku': sku,
      'barcode': barcode,
      'hsnCode': hsnCode,
      'brand': brand,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      'taxPercent': taxPercent,
      'pricingMode': pricingMode,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'categoryId': categoryId,
      'isActive': isActive,
      'isPublished': isPublished,
      'tags': tags,
      'highlights': highlights,
      'specs': specs?.map(_specToJson).toList(),
      'offers': offers?.map((o) => o.toJson()).toList(),
      'contentBlocks': contentBlocks?.map((b) => b.toJson()).toList(),
      'variantAxes': variantAxes?.map((a) => a.toJson()).toList(),
      'variants': variants?.map((v) => v.toJson()).toList(),
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }

  /// Drops empty-row + empty-value pairs before serialising. Lets the
  /// editor leave half-filled rows in the form without ever shipping
  /// them. Phase D: serialises the optional `tab` bucket when set.
  static Map<String, dynamic> _specToJson(SpecGroup g) => {
        'title': g.title.trim(),
        if (g.tab != null && g.tab!.trim().isNotEmpty) 'tab': g.tab!.trim(),
        'rows': g.rows
            .where((r) => r.label.trim().isNotEmpty && r.value.trim().isNotEmpty)
            .map((r) => {'label': r.label.trim(), 'value': r.value.trim()})
            .toList(),
      };
}
