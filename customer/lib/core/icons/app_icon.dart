import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color});

  final AppIconData? icon;

  final double? size;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24.0;
    final glyph = icon;
    return SizedBox.square(
      dimension: resolvedSize,
      child: Center(
        child: glyph == null
            ? const SizedBox.shrink()
            : HugeIcon(
                icon: glyph,
                size: resolvedSize,
                color: color ?? iconTheme.color ?? const Color(0xFF000000),
              ),
      ),
    );
  }
}
