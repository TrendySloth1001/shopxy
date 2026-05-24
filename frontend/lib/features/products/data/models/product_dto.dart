import 'package:shopxy/features/categories/data/models/category_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductDto {
  static ProductImage imageFromJson(Map<String, dynamic> json) => ProductImage(
        id: json['id'] as int,
        productId: json['productId'] as int,
        url: json['url'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
  static ProductImage _imageFromJson(Map<String, dynamic> json) =>
      imageFromJson(json);

  static Product fromJson(Map<String, dynamic> json) {
    final imagesJson = json['images'] as List<dynamic>?;
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      sku: json['sku'] as String,
      barcode: json['barcode'] as String?,
      hsnCode: json['hsnCode'] as String?,
      mrp: _toDouble(json['mrp']),
      sellingPrice: _toDouble(json['sellingPrice']),
      purchasePrice: _toDouble(json['purchasePrice']),
      taxPercent: _toDouble(json['taxPercent']),
      stockQuantity: _toDouble(json['stockQuantity']),
      lowStockThreshold: _toDouble(json['lowStockThreshold']),
      unit: json['unit'] as String? ?? 'PCS',
      categoryId: json['categoryId'] as int?,
      category: json['category'] != null
          ? CategoryDto.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      images: imagesJson?.map((e) => _imageFromJson(e as Map<String, dynamic>)).toList() ?? [],
      lastStockInAt: _parseDate(json['lastStockInAt']),
      lastStockOutAt: _parseDate(json['lastStockOutAt']),
      lastVendorId: (json['lastVendor'] as Map<String, dynamic>?)?['id'] as int?,
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
    List<String>? imageUrls,
    required double mrp,
    required double sellingPrice,
    required double purchasePrice,
    double? taxPercent,
    double? stockQuantity,
    double? lowStockThreshold,
    String? unit,
    int? categoryId,
    List<String>? tags,
    List<String>? highlights,
    List<SpecGroup>? specs,
    List<ProductOffer>? offers,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': (description != null && description.isNotEmpty) ? description : null,
      'sku': sku,
      'barcode': (barcode != null && barcode.isNotEmpty) ? barcode : null,
      'hsnCode': (hsnCode != null && hsnCode.isNotEmpty) ? hsnCode : null,
      'imageUrls': (imageUrls != null && imageUrls.isNotEmpty) ? imageUrls : null,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      'taxPercent': taxPercent,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'categoryId': categoryId,
      'tags': tags,
      'highlights': highlights,
      'specs': specs?.map(_specToJson).toList(),
      'offers': offers?.map((o) => o.toJson()).toList(),
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
    double? mrp,
    double? sellingPrice,
    double? purchasePrice,
    double? taxPercent,
    double? lowStockThreshold,
    String? unit,
    int? categoryId,
    bool? isActive,
    bool? isPublished,
    List<String>? tags,
    List<String>? highlights,
    List<SpecGroup>? specs,
    List<ProductOffer>? offers,
  }) {
    final data = <String, dynamic>{
      'name': name,
      'description': description,
      'sku': sku,
      'barcode': barcode,
      'hsnCode': hsnCode,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      'taxPercent': taxPercent,
      'lowStockThreshold': lowStockThreshold,
      'unit': unit,
      'categoryId': categoryId,
      'isActive': isActive,
      'isPublished': isPublished,
      'tags': tags,
      'highlights': highlights,
      'specs': specs?.map(_specToJson).toList(),
      'offers': offers?.map((o) => o.toJson()).toList(),
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }

  /// Drops empty-row + empty-value pairs before serialising. Lets the
  /// editor leave half-filled rows in the form without ever shipping
  /// them.
  static Map<String, dynamic> _specToJson(SpecGroup g) => {
        'title': g.title.trim(),
        'rows': g.rows
            .where((r) => r.label.trim().isNotEmpty && r.value.trim().isNotEmpty)
            .map((r) => {'label': r.label.trim(), 'value': r.value.trim()})
            .toList(),
      };
}
