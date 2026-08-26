import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.heroImageUrl,
    required this.heroTagline,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showSkip = false,
    this.heroHeight = 300,
  });

  final String heroImageUrl;
  final String heroTagline;
  final String title;
  final String subtitle;
  final Widget child;
  final bool showSkip;
  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: heroHeight + 40,
            child: _HeroArt(imageUrl: heroImageUrl, tagline: heroTagline),
          ),
          Positioned(
            top: heroHeight - 26,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: ShapeDecoration(
                color: AppColors.white,
                shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.xl,
                    AppSizes.xxl,
                    AppSizes.xl,
                    AppSizes.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xl),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (showSkip)
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSizes.xs,
              right: AppSizes.sm,
              child: const _WhiteSkip(),
            ),
        ],
      ),
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.imageUrl, required this.tagline});
  final String imageUrl;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NetworkImageBox(url: imageUrl, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.black.withValues(alpha: 0.302),
                AppColors.black.withValues(alpha: 0),
                AppColors.black.withValues(alpha: 0.502),
                AppColors.black.withValues(alpha: 0.851),
              ],
              stops: const [0.0, 0.32, 0.68, 1.0],
            ),
          ),
        ),
        Positioned(
          left: AppSizes.xl,
          right: AppSizes.xl,
          bottom: 84,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppSizes.xxxl,
                    height: AppSizes.xxxl,
                    decoration: ShapeDecoration(
                      color: AppColors.brand,
                      shape: AppShapes.squircle(AppSizes.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: const AppIcon(
                      AppIcons.storefrontRounded,
                      color: AppColors.white,
                      size: AppSizes.iconMd,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    'shop',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                  Text(
                    'xy.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                tagline,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WhiteSkip extends StatelessWidget {
  const _WhiteSkip();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.white,
            textStyle: Theme.of(context).textTheme.bodyMedium?.bold,
          ),
        ),
      ),
      child: const SkipToGuestButton(),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.autocorrect = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final AppIconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool autocorrect;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: AppIcon(icon, size: AppSizes.iconMd),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: AppIcon(
                  obscure
                      ? AppIcons.visibilityOutlined
                      : AppIcons.visibilityOffOutlined,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.canvas,
      ),
    );
  }
}

class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.errorSoft,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const AppIcon(
            AppIcons.errorOutlineRounded,
            color: AppColors.error,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
