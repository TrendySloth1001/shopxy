import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// Hairline divider. Use between list rows / sections.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = AppSizes.lg, this.endIndent = AppSizes.lg});

  /// Full-width divider with no indent. Use at the edges of cards.
  const AppDivider.flush({super.key}) : indent = 0, endIndent = 0;

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.hairline,
      thickness: 1,
      height: 1,
      indent: indent,
      endIndent: endIndent,
    );
  }
}
