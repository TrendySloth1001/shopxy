import 'package:flutter/material.dart';

/// Curated set of icons offered when creating or editing a category.
///
/// The DB stores the kebab-case key; the merchant app resolves it back
/// to an [IconData] via [resolveCategoryIcon]. Keeping the mapping in a
/// single place means adding a new option only requires touching this
/// file — the picker and tile pick it up automatically.
class CategoryIconOption {
  const CategoryIconOption({
    required this.name,
    required this.icon,
    required this.label,
  });

  final String name;
  final IconData icon;
  final String label;
}

const List<CategoryIconOption> kCategoryIconOptions = [
  CategoryIconOption(
    name: 'grocery',
    icon: Icons.local_grocery_store_rounded,
    label: 'Grocery',
  ),
  CategoryIconOption(
    name: 'kirana',
    icon: Icons.storefront_rounded,
    label: 'Kirana',
  ),
  CategoryIconOption(
    name: 'beverages',
    icon: Icons.local_cafe_rounded,
    label: 'Beverages',
  ),
  CategoryIconOption(
    name: 'bakery',
    icon: Icons.bakery_dining_rounded,
    label: 'Bakery',
  ),
  CategoryIconOption(
    name: 'dairy',
    icon: Icons.icecream_rounded,
    label: 'Dairy',
  ),
  CategoryIconOption(
    name: 'fruits-veg',
    icon: Icons.eco_rounded,
    label: 'Fruits & Veg',
  ),
  CategoryIconOption(
    name: 'meat',
    icon: Icons.kebab_dining_rounded,
    label: 'Meat',
  ),
  CategoryIconOption(
    name: 'pharmacy',
    icon: Icons.medication_rounded,
    label: 'Pharmacy',
  ),
  CategoryIconOption(
    name: 'electronics',
    icon: Icons.devices_other_rounded,
    label: 'Electronics',
  ),
  CategoryIconOption(
    name: 'mobile',
    icon: Icons.smartphone_rounded,
    label: 'Mobile',
  ),
  CategoryIconOption(
    name: 'computer',
    icon: Icons.computer_rounded,
    label: 'Computer',
  ),
  CategoryIconOption(
    name: 'appliance',
    icon: Icons.kitchen_rounded,
    label: 'Appliance',
  ),
  CategoryIconOption(
    name: 'fashion',
    icon: Icons.checkroom_rounded,
    label: 'Fashion',
  ),
  CategoryIconOption(
    name: 'footwear',
    icon: Icons.directions_walk_rounded,
    label: 'Footwear',
  ),
  CategoryIconOption(
    name: 'beauty',
    icon: Icons.spa_rounded,
    label: 'Beauty',
  ),
  CategoryIconOption(
    name: 'jewellery',
    icon: Icons.diamond_rounded,
    label: 'Jewellery',
  ),
  CategoryIconOption(
    name: 'home',
    icon: Icons.chair_rounded,
    label: 'Home',
  ),
  CategoryIconOption(
    name: 'kitchen',
    icon: Icons.restaurant_rounded,
    label: 'Kitchen',
  ),
  CategoryIconOption(
    name: 'cleaning',
    icon: Icons.cleaning_services_rounded,
    label: 'Cleaning',
  ),
  CategoryIconOption(
    name: 'stationery',
    icon: Icons.edit_note_rounded,
    label: 'Stationery',
  ),
  CategoryIconOption(
    name: 'books',
    icon: Icons.menu_book_rounded,
    label: 'Books',
  ),
  CategoryIconOption(
    name: 'toys',
    icon: Icons.toys_rounded,
    label: 'Toys',
  ),
  CategoryIconOption(
    name: 'sports',
    icon: Icons.sports_cricket_rounded,
    label: 'Sports',
  ),
  CategoryIconOption(
    name: 'auto',
    icon: Icons.directions_car_filled_rounded,
    label: 'Auto',
  ),
  CategoryIconOption(
    name: 'hardware',
    icon: Icons.handyman_rounded,
    label: 'Hardware',
  ),
  CategoryIconOption(
    name: 'paint',
    icon: Icons.format_paint_rounded,
    label: 'Paint',
  ),
  CategoryIconOption(
    name: 'plant',
    icon: Icons.local_florist_rounded,
    label: 'Plants',
  ),
  CategoryIconOption(
    name: 'gift',
    icon: Icons.card_giftcard_rounded,
    label: 'Gift',
  ),
  CategoryIconOption(
    name: 'pet',
    icon: Icons.pets_rounded,
    label: 'Pet',
  ),
  CategoryIconOption(
    name: 'service',
    icon: Icons.miscellaneous_services_rounded,
    label: 'Service',
  ),
];

/// Resolves a stored icon name to an [IconData]. Falls back to a
/// neutral category glyph when the name is null or unknown — keeps
/// legacy rows rendering without a crash.
IconData resolveCategoryIcon(String? name) {
  if (name == null) return Icons.category_rounded;
  for (final opt in kCategoryIconOptions) {
    if (opt.name == name) return opt.icon;
  }
  return Icons.category_rounded;
}
