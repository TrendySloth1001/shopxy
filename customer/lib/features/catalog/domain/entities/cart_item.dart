import 'package:shopxy_customer/features/catalog/domain/entities/catalog_product.dart';

class CartItem {
  CartItem({required this.product, this.quantity = 1});
  final CatalogProduct product;
  double quantity;

  double get lineTotal => quantity * product.sellingPrice;
}
