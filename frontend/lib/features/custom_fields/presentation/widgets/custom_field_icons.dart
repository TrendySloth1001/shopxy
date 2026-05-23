import 'package:flutter/material.dart';

/// Curated palette of Material icons available for custom-field
/// sections and individual fields. We deliberately don't ship the
/// whole Material icon set — too many choices makes picking slow, and
/// it inflates the tree-shaking surface.
///
/// Names here are the **string keys** that get persisted to the
/// backend. Add to this map (don't remove) when you want to expose
/// more icons; existing rows that reference a removed name will fall
/// back to [kFallbackCustomFieldIcon].
const Map<String, IconData> kCustomFieldIcons = {
  // General
  'inventory_2': Icons.inventory_2_rounded,
  'tag': Icons.tag_rounded,
  'label': Icons.label_rounded,
  'description': Icons.description_rounded,
  'category': Icons.category_rounded,
  'star': Icons.star_rounded,
  'info': Icons.info_rounded,
  'tune': Icons.tune_rounded,
  'settings': Icons.settings_rounded,
  'build': Icons.build_rounded,

  // Warranty / certification
  'verified': Icons.verified_rounded,
  'verified_user': Icons.verified_user_rounded,
  'fact_check': Icons.fact_check_rounded,
  'shield': Icons.shield_rounded,

  // Electronics
  'memory': Icons.memory_rounded,
  'bolt': Icons.bolt_rounded,
  'flash_on': Icons.flash_on_rounded,
  'power': Icons.power_rounded,
  'devices': Icons.devices_rounded,
  'battery_full': Icons.battery_full_rounded,

  // Logistics / packaging
  'local_shipping': Icons.local_shipping_rounded,
  'scale': Icons.scale_rounded,
  'straighten': Icons.straighten_rounded,
  'warning': Icons.warning_amber_rounded,
  'inventory': Icons.inventory_rounded,

  // Apparel
  'checkroom': Icons.checkroom_rounded,
  'palette': Icons.palette_rounded,
  'texture': Icons.texture_rounded,
  'people': Icons.people_rounded,

  // Food / consumables
  'restaurant': Icons.restaurant_rounded,
  'eco': Icons.eco_rounded,
  'factory': Icons.factory_rounded,
  'event': Icons.event_rounded,
  'event_busy': Icons.event_busy_rounded,

  // Misc
  'qr_code_2': Icons.qr_code_2_rounded,
  'calendar_today': Icons.calendar_today_rounded,
  'attach_money': Icons.currency_rupee_rounded,
  'place': Icons.place_rounded,
};

/// Used when a row references an icon name that's no longer in the
/// palette. Picked a quiet generic glyph so the cell still looks
/// intentional.
const IconData kFallbackCustomFieldIcon = Icons.label_outline_rounded;

/// Resolve a stored icon name to an actual [IconData]. Falls back to
/// the generic label if the name is unknown or null.
IconData resolveCustomFieldIcon(String? name) {
  if (name == null || name.isEmpty) return kFallbackCustomFieldIcon;
  return kCustomFieldIcons[name] ?? kFallbackCustomFieldIcon;
}
