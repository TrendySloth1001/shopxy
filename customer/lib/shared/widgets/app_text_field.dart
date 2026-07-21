import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// The one text-field widget for the app. Wraps Material's [TextField]
/// with consistent shape, label-above pattern, helper/error below, and
/// a 48dp minimum tap target — all per `DESIGN.md` rules.
///
/// Label is rendered outside the input (Material 3's "outlined with
/// floating label" looks busy on a phone — outside-label keeps the
/// content density honest).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final AppIconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
        ],
        TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: minLines,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.black),
          cursorColor: AppColors.brand,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.subtle,
            ),
            counterText: '',
            filled: true,
            fillColor: enabled ? AppColors.white : AppColors.surfaceTint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.md + 2,
            ),
            prefixIcon: prefixIcon == null
                ? null
                : AppIcon(
                    prefixIcon,
                    size: AppSizes.iconMd,
                    color: AppColors.muted,
                  ),
            suffixIcon: suffixIcon,
            border: _border(AppColors.hairline),
            enabledBorder: _border(AppColors.hairline),
            focusedBorder: _border(AppColors.black, width: 1.4),
            disabledBorder: _border(AppColors.hairline),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error, width: 1.4),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSizes.xs),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ] else if (helper != null && helper!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.xs),
          Text(
            helper!,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
