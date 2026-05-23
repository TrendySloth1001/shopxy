import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Non-editable search bar that sits on the Home page. Tapping it
/// opens the dedicated search route (set up in a later milestone) —
/// keeps the home page from owning the input focus state and lets the
/// search page take full screen with autocomplete + recent searches.
class HomeSearchEntry extends StatelessWidget {
  const HomeSearchEntry({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusInput,
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: AppShapes.squircle(AppSizes.radiusInput),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.md + 2,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: AppSizes.iconMd,
                  color: AppColors.muted,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Text(
                    AppStrings.searchProducts,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.subtle,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 2,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.surfaceTint,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 14,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
