import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// ─────────────────────────────────────────────────────────────────────
/// GlassPage — Glassdoor-style page scaffold.
///
/// Anatomy:
///   ┌──────────────────────────────┐
///   │ [progress bar — optional]    │
///   ├──────────────────────────────┤
///   │   [hero panel (gray bg)]     │  ← illustration zone
///   ├──────────────────────────────┤
///   │  Title                       │
///   │  Body copy …                 │
///   │  [content slot]              │
///   ├──────────────────────────────┤
///   │  [Primary CTA]               │
///   │  [Secondary text-link]       │
///   └──────────────────────────────┘
///
/// Optional [navButton] floats over the top-left corner — the Glassdoor
/// chunky black circle back arrow.
/// ─────────────────────────────────────────────────────────────────────
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

  /// The hero panel (illustration + soft gray background). Pass [null] to
  /// skip — useful for list-style pages that don't need a top zone.
  final Widget? hero;

  /// Big bold headline directly under the hero zone.
  final String? title;

  /// Calm secondary copy below the title.
  final String? subtitle;

  /// Main content slot — forms, lists, anything.
  final Widget? body;

  /// Bottom action area — typically a [GlassActionPanel].
  final Widget? actions;

  /// Optional top segmented progress bar — pass a value in [0,1].
  final double? progress;

  /// Optional floating back/forward button — see [GlassNavButton].
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

/// ─────────────────────────────────────────────────────────────────────
/// GlassHero — the soft gray top panel that houses an illustration.
/// ─────────────────────────────────────────────────────────────────────
class GlassHero extends StatelessWidget {
  const GlassHero({
    super.key,
    required this.illustration,
    this.height = 240,
    this.backgroundColor,
  });

  /// Convenience constructor for the bundled [LineArt] illustrations.
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

  /// Convenience constructor for raster (PNG) illustrations sitting on
  /// the soft hero panel. The image is contained inside vertical
  /// padding so it never bleeds into the title below.
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

  /// Hero panel fill. Defaults to [AppColors.heroPanel] (theme-aware) when null
  /// — can't be a const default now that AppColors are getters.
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

/// ─────────────────────────────────────────────────────────────────────
/// GlassProgressBar — segmented green progress at the very top.
///
/// Two-tone fill: filled portion is brand-green, unfilled is a tiny
/// hairline strip. Used in onboarding / multi-step flows.
/// ─────────────────────────────────────────────────────────────────────
class GlassProgressBar extends StatelessWidget {
  const GlassProgressBar({super.key, required this.value, this.steps = 0});

  /// Progress in [0, 1].
  final double value;

  /// If > 0, renders as discrete segments with small gaps between.
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

/// ─────────────────────────────────────────────────────────────────────
/// GlassNavButton — the chunky black circular button with a white chevron.
///
///   ●←   for back   ●→   for forward
/// ─────────────────────────────────────────────────────────────────────
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

  /// Chevron colour. Defaults to [AppColors.onInverse] (theme-aware).
  final Color? foreground;

  /// Circle fill — a high-contrast neutral. Defaults to [AppColors.inverseSurface].
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

/// ─────────────────────────────────────────────────────────────────────
/// GlassActionPanel — primary CTA + optional secondary text link, pinned
/// to the bottom of the page with a hairline divider above.
/// ─────────────────────────────────────────────────────────────────────
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

  /// Optional override for the primary button color — pass [AppColors.brand]
  /// when you want a Glassdoor-green CTA instead of the default neutral.
  final Color? primaryColor;

  /// Panel fill. Defaults to [AppColors.surface] (theme-aware) when null.
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

/// Internal pill-shaped CTA. We keep this separate from [AppButton] so the
/// Glassdoor language stays distinct — larger touch target, fully rounded,
/// no border. Use [AppButton] for inline buttons inside forms; use this
/// only via [GlassActionPanel].
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

/// Re-export so callers can `import 'glass_widgets.dart'` and get the
/// button enum without an extra import.
typedef GlassButton = AppButton;
