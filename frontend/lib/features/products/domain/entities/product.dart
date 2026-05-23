import 'package:shopxy/features/categories/domain/entities/category.dart';

class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.url,
    required this.sortOrder,
    required this.createdAt,
  });

  final int id;
  final int productId;
  final String url;
  final int sortOrder;
  final DateTime createdAt;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.sku,
    this.barcode,
    this.hsnCode,
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
    this.images = const [],
    this.lastStockInAt,
    this.lastStockOutAt,
    this.lastVendorId,
    this.lastVendorName,
  });

  final int id;
  final String name;
  final String? description;
  final String sku;
  final String? barcode;
  final String? hsnCode;
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
  final List<ProductImage> images;

  /// Most recent STOCK_IN ledger timestamp for this product, when one exists.
  /// Powers the "Stocked in 2d ago" hint on the merchant product list.
  final DateTime? lastStockInAt;

  /// Most recent STOCK_OUT ledger timestamp. Used for "Sold 3d ago" and
  /// "Out since 5d ago" framings.
  final DateTime? lastStockOutAt;

  /// Vendor id for the supplier of the most recent STOCK_IN, when the
  /// transaction recorded a real vendor (not a free-text supplier).
  final int? lastVendorId;

  /// Vendor display name paired with [lastVendorId].
  final String? lastVendorName;

  String? get primaryImageUrl => images.isNotEmpty ? images.first.url : null;
  bool get isLowStock => stockQuantity <= lowStockThreshold && stockQuantity > 0;
  bool get isOutOfStock => stockQuantity <= 0;
  double get profit => sellingPrice - purchasePrice;
  double get margin => purchasePrice > 0 ? (profit / sellingPrice) * 100 : 0;
}
