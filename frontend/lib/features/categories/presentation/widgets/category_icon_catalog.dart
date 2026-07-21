import 'package:flutter/material.dart';
import 'package:shopxy/core/icons/app_icons.dart';

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
    icon: AppIcons.localGroceryStoreRounded,
    label: 'Grocery',
  ),
  CategoryIconOption(
    name: 'kirana',
    icon: AppIcons.storefrontRounded,
    label: 'Kirana',
  ),
  CategoryIconOption(
    name: 'beverages',
    icon: AppIcons.localCafeRounded,
    label: 'Beverages',
  ),
  CategoryIconOption(
    name: 'bakery',
    icon: AppIcons.bakeryDiningRounded,
    label: 'Bakery',
  ),
  CategoryIconOption(
    name: 'dairy',
    icon: AppIcons.icecreamRounded,
    label: 'Dairy',
  ),
  CategoryIconOption(
    name: 'fruits-veg',
    icon: AppIcons.ecoRounded,
    label: 'Fruits & Veg',
  ),
  CategoryIconOption(
    name: 'meat',
    icon: AppIcons.kebabDiningRounded,
    label: 'Meat',
  ),
  CategoryIconOption(
    name: 'pharmacy',
    icon: AppIcons.medicationRounded,
    label: 'Pharmacy',
  ),
  CategoryIconOption(
    name: 'electronics',
    icon: AppIcons.devicesOtherRounded,
    label: 'Electronics',
  ),
  CategoryIconOption(
    name: 'mobile',
    icon: AppIcons.smartphoneRounded,
    label: 'Mobile',
  ),
  CategoryIconOption(
    name: 'computer',
    icon: AppIcons.computerRounded,
    label: 'Computer',
  ),
  CategoryIconOption(
    name: 'appliance',
    icon: AppIcons.kitchenRounded,
    label: 'Appliance',
  ),
  CategoryIconOption(
    name: 'fashion',
    icon: AppIcons.checkroomRounded,
    label: 'Fashion',
  ),
  CategoryIconOption(
    name: 'footwear',
    icon: AppIcons.directionsWalkRounded,
    label: 'Footwear',
  ),
  CategoryIconOption(
    name: 'beauty',
    icon: AppIcons.spaRounded,
    label: 'Beauty',
  ),
  CategoryIconOption(
    name: 'jewellery',
    icon: AppIcons.diamondRounded,
    label: 'Jewellery',
  ),
  CategoryIconOption(
    name: 'home',
    icon: AppIcons.chairRounded,
    label: 'Home',
  ),
  CategoryIconOption(
    name: 'kitchen',
    icon: AppIcons.restaurantRounded,
    label: 'Kitchen',
  ),
  CategoryIconOption(
    name: 'cleaning',
    icon: AppIcons.cleaningServicesRounded,
    label: 'Cleaning',
  ),
  CategoryIconOption(
    name: 'stationery',
    icon: AppIcons.editNoteRounded,
    label: 'Stationery',
  ),
  CategoryIconOption(
    name: 'books',
    icon: AppIcons.menuBookRounded,
    label: 'Books',
  ),
  CategoryIconOption(
    name: 'toys',
    icon: AppIcons.toysRounded,
    label: 'Toys',
  ),
  CategoryIconOption(
    name: 'sports',
    icon: AppIcons.sportsCricketRounded,
    label: 'Sports',
  ),
  CategoryIconOption(
    name: 'auto',
    icon: AppIcons.directionsCarFilledRounded,
    label: 'Auto',
  ),
  CategoryIconOption(
    name: 'hardware',
    icon: AppIcons.handymanRounded,
    label: 'Hardware',
  ),
  CategoryIconOption(
    name: 'paint',
    icon: AppIcons.formatPaintRounded,
    label: 'Paint',
  ),
  CategoryIconOption(
    name: 'plant',
    icon: AppIcons.localFloristRounded,
    label: 'Plants',
  ),
  CategoryIconOption(
    name: 'gift',
    icon: AppIcons.cardGiftcardRounded,
    label: 'Gift',
  ),
  CategoryIconOption(
    name: 'pet',
    icon: AppIcons.petsRounded,
    label: 'Pet',
  ),
  CategoryIconOption(
    name: 'service',
    icon: AppIcons.miscellaneousServicesRounded,
    label: 'Service',
  ),
];

/// Resolves a stored icon name to an [IconData]. Falls back to a
/// neutral category glyph when the name is null or unknown — keeps
/// legacy rows rendering without a crash.
IconData resolveCategoryIcon(String? name) {
  if (name == null) return AppIcons.categoryRounded;
  for (final opt in kCategoryIconOptions) {
    if (opt.name == name) return opt.icon;
  }
  return AppIcons.categoryRounded;
}
