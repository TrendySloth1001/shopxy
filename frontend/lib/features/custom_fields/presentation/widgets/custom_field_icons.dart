import 'package:shopxy/core/icons/app_icons.dart';

const Map<String, AppIconData> kCustomFieldIcons = {
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

  'verified': AppIcons.verifiedRounded,
  'verified_user': AppIcons.verifiedUserRounded,
  'fact_check': AppIcons.factCheckRounded,
  'shield': AppIcons.shieldRounded,

  'memory': AppIcons.memoryRounded,
  'bolt': AppIcons.boltRounded,
  'flash_on': AppIcons.flashOnRounded,
  'power': AppIcons.powerRounded,
  'devices': AppIcons.devicesRounded,
  'battery_full': AppIcons.batteryFullRounded,

  'local_shipping': AppIcons.localShippingRounded,
  'scale': AppIcons.scaleRounded,
  'straighten': AppIcons.straightenRounded,
  'warning': AppIcons.warningAmberRounded,
  'inventory': AppIcons.inventoryRounded,

  'checkroom': AppIcons.checkroomRounded,
  'palette': AppIcons.paletteRounded,
  'texture': AppIcons.textureRounded,
  'people': AppIcons.peopleRounded,

  'restaurant': AppIcons.restaurantRounded,
  'eco': AppIcons.ecoRounded,
  'factory': AppIcons.factoryRounded,
  'event': AppIcons.eventRounded,
  'event_busy': AppIcons.eventBusyRounded,

  'qr_code_2': AppIcons.qrCode2Rounded,
  'calendar_today': AppIcons.calendarTodayRounded,
  'attach_money': AppIcons.currencyRupeeRounded,
  'place': AppIcons.placeRounded,
};

const AppIconData kFallbackCustomFieldIcon = AppIcons.labelOutlineRounded;

AppIconData resolveCustomFieldIcon(String? name) {
  if (name == null || name.isEmpty) return kFallbackCustomFieldIcon;
  return kCustomFieldIcons[name] ?? kFallbackCustomFieldIcon;
}
