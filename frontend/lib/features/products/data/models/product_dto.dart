import 'package:shopxy/features/categories/data/models/category_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductDto {
  static ProductImage _imageFromJson(Map<String, dynamic> json) => ProductImage(
        id: json['id'] as int,
        productId: json['productId'] as int,
        url: json['url'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

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
    );
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
    };
    data.removeWhere((_, value) => value == null);
    return data;
  }
}
