import 'package:flutter/material.dart';
import 'package:shopxy/core/icons/app_icons.dart';

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
  'inventory_2': AppIcons.inventory2Rounded,
  'tag': AppIcons.tagRounded,
  'label': AppIcons.labelRounded,
  'description': AppIcons.descriptionRounded,
  'category': AppIcons.categoryRounded,
  'star': AppIcons.starRounded,
  'info': AppIcons.infoRounded,
  'tune': AppIcons.tuneRounded,
  'settings': AppIcons.settingsRounded,
  'build': AppIcons.buildRounded,

  // Warranty / certification
  'verified': AppIcons.verifiedRounded,
  'verified_user': AppIcons.verifiedUserRounded,
  'fact_check': AppIcons.factCheckRounded,
  'shield': AppIcons.shieldRounded,

  // Electronics
  'memory': AppIcons.memoryRounded,
  'bolt': AppIcons.boltRounded,
  'flash_on': AppIcons.flashOnRounded,
  'power': AppIcons.powerRounded,
  'devices': AppIcons.devicesRounded,
  'battery_full': AppIcons.batteryFullRounded,

  // Logistics / packaging
  'local_shipping': AppIcons.localShippingRounded,
  'scale': AppIcons.scaleRounded,
  'straighten': AppIcons.straightenRounded,
  'warning': AppIcons.warningAmberRounded,
  'inventory': AppIcons.inventoryRounded,

  // Apparel
  'checkroom': AppIcons.checkroomRounded,
  'palette': AppIcons.paletteRounded,
  'texture': AppIcons.textureRounded,
  'people': AppIcons.peopleRounded,

  // Food / consumables
  'restaurant': AppIcons.restaurantRounded,
  'eco': AppIcons.ecoRounded,
  'factory': AppIcons.factoryRounded,
  'event': AppIcons.eventRounded,
  'event_busy': AppIcons.eventBusyRounded,

  // Misc
  'qr_code_2': AppIcons.qrCode2Rounded,
  'calendar_today': AppIcons.calendarTodayRounded,
  'attach_money': AppIcons.currencyRupeeRounded,
  'place': AppIcons.placeRounded,
};

/// Used when a row references an icon name that's no longer in the
/// palette. Picked a quiet generic glyph so the cell still looks
/// intentional.
const IconData kFallbackCustomFieldIcon = AppIcons.labelOutlineRounded;

/// Resolve a stored icon name to an actual [IconData]. Falls back to
/// the generic label if the name is unknown or null.
IconData resolveCustomFieldIcon(String? name) {
  if (name == null || name.isEmpty) return kFallbackCustomFieldIcon;
  return kCustomFieldIcons[name] ?? kFallbackCustomFieldIcon;
}
