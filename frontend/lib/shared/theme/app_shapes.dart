import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';

class AppShapes {
  AppShapes._();

  static SmoothRectangleBorder squircle(
    double radius, {
    BorderSide? side,
  }) {
    return SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(
        cornerRadius: radius,
        cornerSmoothing: 1.0, // iOS style continuous curves
      ),
      side: side ?? BorderSide.none,
    );
  }

  static SmoothRectangleBorder squircleTop(
    double radius, {
    BorderSide? side,
  }) {
    return SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius.vertical(
        top: SmoothRadius(cornerRadius: radius, cornerSmoothing: 1.0),
      ),
      side: side ?? BorderSide.none,
    );
  }

  static SmoothBorderRadius squircleRadius(double radius) {
    return SmoothBorderRadius(
      cornerRadius: radius,
      cornerSmoothing: 1.0,
    );
  }

  static SmoothBorderRadius squircleTopRadius(double radius) {
    return SmoothBorderRadius.vertical(
      top: SmoothRadius(cornerRadius: radius, cornerSmoothing: 1.0),
    );
  }
}
