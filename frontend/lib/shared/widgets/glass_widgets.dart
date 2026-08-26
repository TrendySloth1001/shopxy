import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class GlassPage extends StatelessWidget {
  const GlassPage({
    super.key,
    this.hero,
    this.title,
    this.subtitle,
    this.body,
    this.actions,
    this.progress,
    this.navButton,
    this.scrollable = true,
    this.backgroundColor,
  });

  final Widget? hero;

  final String? title;

  final String? subtitle;

  final Widget? body;

  final Widget? actions;

  final double? progress;

  final Widget? navButton;

  final bool scrollable;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null)
          GlassProgressBar(value: progress!.clamp(0.0, 1.0)),
        ?hero,
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.xl,
            AppSizes.xl,
            AppSizes.xl,
            AppSizes.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              if (title != null && subtitle != null)
                const SizedBox(height: AppSizes.sm),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              if (body != null) ...[const SizedBox(height: AppSizes.xl), body!],
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.canvas,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: scrollable
                ? SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: actions != null ? 120 : AppSizes.xl,
                    ),
                    child: content,
                  )
                : content,
          ),
          if (navButton != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + AppSizes.md,
              left: AppSizes.md,
              child: navButton!,
            ),
          if (actions != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: actions!),
            ),
        ],
      ),
    );
  }
}

class GlassHero extends StatelessWidget {
  const GlassHero({
    super.key,
    required this.illustration,
    this.height = 240,
    this.backgroundColor,
  });

  GlassHero.line({
    Key? key,
    required LineArt kind,
    double illustrationSize = 160,
    double height = 240,
    Color? accent,
    Color? backgroundColor,
  }) : this(
         key: key,
         illustration: LineIllustration(
           kind: kind,
           size: illustrationSize,
           accent: accent ?? AppColors.brand,
         ),
         height: height,
         backgroundColor: backgroundColor,
       );

  GlassHero.image({
    Key? key,
    required String asset,
    double height = 260,
    double verticalPadding = AppSizes.xl,
    Color? backgroundColor,
  }) : this(
         key: key,
         illustration: Padding(
           padding: EdgeInsets.symmetric(vertical: verticalPadding),
           child: Image.asset(asset, fit: BoxFit.contain),
         ),
         height: height,
         backgroundColor: backgroundColor,
       );

  final Widget illustration;
  final double height;

  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: backgroundColor ?? AppColors.heroPanel,
      alignment: Alignment.center,
      child: illustration,
    );
  }
}

class GlassProgressBar extends StatelessWidget {
  const GlassProgressBar({super.key, required this.value, this.steps = 0});

  final double value;

  final int steps;

  @override
  Widget build(BuildContext context) {
    if (steps > 0) {
      return Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Row(
          children: List.generate(steps, (i) {
            final filled = (i + 1) / steps <= value + 1e-6;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == steps - 1 ? 0 : AppSizes.xs,
                ),
                child: Container(
                  height: AppSizes.xs,
                  color: filled ? AppColors.brand : AppColors.hairline,
                ),
              ),
            );
          }),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Stack(
        children: [
          Container(height: AppSizes.xs, color: AppColors.hairline),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(height: AppSizes.xs, color: AppColors.brand),
          ),
        ],
      ),
    );
  }
}

class GlassNavButton extends StatelessWidget {
  const GlassNavButton({
    super.key,
    required this.onPressed,
    this.direction = GlassNavDirection.back,
    this.size = 52,
    this.foreground,
    this.background,
  });

  final VoidCallback onPressed;
  final GlassNavDirection direction;
  final double size;

  final Color? foreground;

  final Color? background;

  @override
  Widget build(BuildContext context) {
    final icon = switch (direction) {
      GlassNavDirection.back => AppIcons.arrowBackRounded,
      GlassNavDirection.forward => AppIcons.arrowForwardRounded,
      GlassNavDirection.close => AppIcons.closeRounded,
    };
    return Material(
      color: background ?? AppColors.inverseSurface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: AppIcon(
            icon,
            color: foreground ?? AppColors.onInverse,
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}

enum GlassNavDirection { back, forward, close }

class GlassActionPanel extends StatelessWidget {
  const GlassActionPanel({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.primaryLoading = false,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryColor,
    this.background,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final AppIconData? primaryIcon;
  final bool primaryLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final Color? primaryColor;

  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xl,
        AppSizes.md,
        AppSizes.xl,
        AppSizes.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: _PillButton(
              label: primaryLabel,
              icon: primaryIcon,
              loading: primaryLoading,
              onPressed: onPrimary,
              color: primaryColor ?? AppColors.inverseSurface,
            ),
          ),
          if (secondaryLabel != null) ...[
            const SizedBox(height: AppSizes.xs),
            TextButton(
              onPressed: onSecondary,
              child: Text(
                secondaryLabel!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    required this.color,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final AppIconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: onPressed == null ? AppColors.disabled : color,
      shape: AppShapes.squircle(28),
      child: InkWell(
        customBorder: AppShapes.squircle(28),
        onTap: loading ? null : onPressed,
        child: Container(
          height: AppSizes.fabSize,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: loading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: AppColors.onInverse,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      AppIcon(
                        icon,
                        color: AppColors.onInverse,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSizes.sm),
                    ],
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.onInverse,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

typedef GlassButton = AppButton;
