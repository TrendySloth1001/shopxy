import 'package:flutter/material.dart';
import 'package:shopxy/shared/theme/app_palette.dart';

class AppColors {
  AppColors._();

  static AppPalette get _p => AppPalette.active;

  static Color get black => _p.ink;

  static Color get white => _p.onAccent;

  static Color get hairline => _p.hairline;

  static Color get surfaceTint => _p.surfaceTint;

  static Color get muted => _p.muted;

  static Color get subtle => _p.subtle;

  static Color get disabled => _p.disabled;

  static Color get canvas => _p.canvas;

  static Color get pageTint => _p.pageTint;

  static Color get heroPanel => _p.heroPanel;

  static Color get surface => _p.surface;

  static Color get field => _p.field;

  static Color get inverseSurface => _p.inverseSurface;

  static Color get onInverse => _p.onInverse;

  static Color get scrim => _p.scrim;

  static Color get shadow => _p.shadow;

  static Color get brand => _p.brand;
  static Color get brandStrong => _p.brandStrong;
  static Color get brandSoft => _p.brandSoft;

  static Color get success => _p.success;
  static Color get successSoft => _p.successSoft;
  static Color get warning => _p.warning;
  static Color get warningSoft => _p.warningSoft;
  static Color get error => _p.error;
  static Color get errorSoft => _p.errorSoft;
  static Color get info => _p.info;
  static Color get infoSoft => _p.infoSoft;

  static Color get accentTeal => _p.accentTeal;
  static Color get accentTealSoft => _p.accentTealSoft;
  static Color get accentIndigo => _p.accentIndigo;
  static Color get accentIndigoSoft => _p.accentIndigoSoft;
  static Color get accentAmber => _p.accentAmber;
  static Color get accentAmberSoft => _p.accentAmberSoft;
  static Color get accentRose => _p.accentRose;
  static Color get accentRoseSoft => _p.accentRoseSoft;

  static Color get flashDeal => _p.flashDeal;
  static Color get flashDealSoft => _p.flashDealSoft;
  static Color get flashDealSoftAlt => _p.flashDealSoftAlt;
  static Color get whatsapp => _p.whatsapp;

  static Color tileBg(Color softInLight) =>
      _p.isDark ? _p.heroPanel : softInLight;
}
