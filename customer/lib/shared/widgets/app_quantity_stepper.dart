import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class AppQuantityStepper extends StatelessWidget {
  const AppQuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.maxQuantity,
    this.minQuantity = 0,
    this.addLabel = 'Add',
    this.dense = false,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  final int? maxQuantity;

  final int minQuantity;

  final String addLabel;

  final bool dense;

  bool get _canDec => quantity > minQuantity;
  bool get _canInc => maxQuantity == null || quantity < maxQuantity!;

  double get _height => dense ? 36 : AppSizes.tapTargetMin;
  double get _iconSize => dense ? AppSizes.iconSm : 18;
  double get _hPad => dense ? AppSizes.sm : AppSizes.md;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (quantity <= 0) {
      return SizedBox(
        height: _height,
        child: Material(
          color: AppColors.black,
          shape: AppShapes.squircle(AppSizes.radiusButton),
          child: InkWell(
            onTap: _canInc ? () => onChanged(quantity + 1) : null,
            customBorder: AppShapes.squircle(AppSizes.radiusButton),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _hPad + 4),
              child: Center(
                child: Text(
                  addLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: dense ? 13 : 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _height,
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusButton,
          side: const BorderSide(color: AppColors.black, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(
              icon: quantity == minQuantity + 1 && minQuantity == 0
                  ? AppIcons.deleteOutlineRounded
                  : AppIcons.removeRounded,
              enabled: _canDec,
              iconSize: _iconSize,
              hPad: _hPad,
              onTap: () => onChanged(quantity - 1),
            ),
            SizedBox(
              width: dense ? AppSizes.xxl : AppSizes.xxxl,
              child: Center(
                child: Text(
                  '$quantity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: dense ? 14 : 16,
                  ),
                ),
              ),
            ),
            _StepperButton(
              icon: AppIcons.addRounded,
              enabled: _canInc,
              iconSize: _iconSize,
              hPad: _hPad,
              onTap: () => onChanged(quantity + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.iconSize,
    required this.hPad,
  });
  final AppIconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final double iconSize;
  final double hPad;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      customBorder: AppShapes.squircle(AppSizes.radiusButton),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPad),
        child: AppIcon(
          icon,
          size: iconSize,
          color: enabled ? AppColors.black : AppColors.disabled,
        ),
      ),
    );
  }
}
