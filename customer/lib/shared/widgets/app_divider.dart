import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = AppSizes.lg, this.endIndent = AppSizes.lg});

  const AppDivider.flush({super.key}) : indent = 0, endIndent = 0;

  const AppDivider.inset({super.key, double leading = 56})
      : indent = leading,
        endIndent = 0;

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
