import 'package:flutter/animation.dart';

abstract final class AppCurves {
  AppCurves._();

  static const Curve standard = Curves.easeInOut;

  static const Curve standardEmphasized = Curves.easeInOutCubic;

  static const Curve decelerate = Curves.easeOut;

  static const Curve decelerateEmphasized = Curves.easeOutCubic;
}
