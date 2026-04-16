import 'package:flutter/material.dart';

class AppShapes {
  AppShapes._();

  static ContinuousRectangleBorder squircle(
    double radius, {
    BorderSide? side,
  }) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: side ?? BorderSide.none,
    );
  }

  static ContinuousRectangleBorder squircleTop(
    double radius, {
    BorderSide? side,
  }) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      side: side ?? BorderSide.none,
    );
  }

  static BorderRadius squircleRadius(double radius) {
    return BorderRadius.circular(radius);
  }

  static BorderRadius squircleTopRadius(double radius) {
    return BorderRadius.vertical(top: Radius.circular(radius));
  }
}
