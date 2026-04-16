import 'package:shopxy/features/categories/data/models/category_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';

class ProductDto {
  static Product fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      sku: json['sku'] as String,
      barcode: json['barcode'] as String?,
      hsnCode: json['hsnCode'] as String?,
      imageUrl: json['imageUrl'] as String?,
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
    String? imageUrl,
    required double mrp,
    required double sellingPrice,
    required double purchasePrice,
    double? taxPercent,
    double? stockQuantity,
    double? lowStockThreshold,
    String? unit,
    int? categoryId,
  }) {
    return {
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      'sku': sku,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
      if (hsnCode != null && hsnCode.isNotEmpty) 'hsnCode': hsnCode,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'mrp': mrp,
      'sellingPrice': sellingPrice,
      'purchasePrice': purchasePrice,
      if (taxPercent != null) 'taxPercent': taxPercent,
      if (stockQuantity != null) 'stockQuantity': stockQuantity,
      if (lowStockThreshold != null) 'lowStockThreshold': lowStockThreshold,
      if (unit != null) 'unit': unit,
      if (categoryId != null) 'categoryId': categoryId,
    };
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? description,
    String? sku,
    String? barcode,
    String? hsnCode,
    String? imageUrl,
    double? mrp,
    double? sellingPrice,
    double? purchasePrice,
    double? taxPercent,
    double? lowStockThreshold,
    String? unit,
    int? categoryId,
    bool? isActive,
  }) {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (hsnCode != null) 'hsnCode': hsnCode,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (mrp != null) 'mrp': mrp,
      if (sellingPrice != null) 'sellingPrice': sellingPrice,
      if (purchasePrice != null) 'purchasePrice': purchasePrice,
      if (taxPercent != null) 'taxPercent': taxPercent,
      if (lowStockThreshold != null) 'lowStockThreshold': lowStockThreshold,
      if (unit != null) 'unit': unit,
      if (categoryId != null) 'categoryId': categoryId,
      if (isActive != null) 'isActive': isActive,
    };
  }
}
