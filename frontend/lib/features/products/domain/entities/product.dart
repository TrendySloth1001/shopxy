import 'package:shopxy/features/categories/domain/entities/category.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.sku,
    this.barcode,
    this.hsnCode,
    this.imageUrl,
    required this.mrp,
    required this.sellingPrice,
    required this.purchasePrice,
    required this.taxPercent,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.unit,
    this.categoryId,
    this.category,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final String sku;
  final String? barcode;
  final String? hsnCode;
  final String? imageUrl;
  final double mrp;
  final double sellingPrice;
  final double purchasePrice;
  final double taxPercent;
  final double stockQuantity;
  final double lowStockThreshold;
  final String unit;
  final int? categoryId;
  final Category? category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => stockQuantity <= lowStockThreshold && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;
  double get profit => sellingPrice - purchasePrice;
  double get margin => purchasePrice > 0 ? (profit / sellingPrice) * 100 : 0;
}
