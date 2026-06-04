import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Mirror of the polished customer-side hero card so the merchant
/// editor preview shows exactly what will ship. Same shadows,
/// gradients, animations (shimmer / glow-pulse / Ken Burns) and
/// display typography — fed by a simple data class that the editor
/// builds from its form state on every keystroke.
///
/// Lives in the merchant project as a sibling copy (per the project's
/// "duplicate, don't extract" rule for shared customer/merchant code).
class HeroSlidePreviewData {
  const HeroSlidePreviewData({
    required this.template,
    this.imageFit = BannerImageFit.cover,
    required this.title,
    this.subtitle,
    this.brandLabel,
    this.brandImageUrl,
    this.brandImageFit = BannerImageFit.cover,
    this.eyebrow,
    this.ctaText,
    this.imageUrl,
    required this.bgColor,
    required this.accent,
  });

  final BannerTemplate template;
  final BannerImageFit imageFit;
  final String title;
  final String? subtitle;
  final String? brandLabel;
  /// Optional shop logo — when set, every templated card swaps the
  /// brand text chip for this image. Null falls back to the text label.
  final String? brandImageUrl;
  final BannerImageFit brandImageFit;
  /// Tiny copy above the title — used to be silently dropped because
  /// the data class didn't include it. Every templated card that has
  /// room for tagline-style copy renders this when non-empty.
  final String? eyebrow;
  final String? ctaText;
  final String? imageUrl;
  final Color bgColor;
  final Color accent;

  BoxFit get boxFit =>
      imageFit == BannerImageFit.contain ? BoxFit.contain : BoxFit.cover;

  String get _resolvedCta {
    final t = ctaText?.trim();
    return (t == null || t.isEmpty) ? 'Shop now' : t;
  }

  String get _resolvedBrand => brandLabel?.trim() ?? '';
  String get _resolvedSubtitle => subtitle?.trim() ?? '';
  String get _resolvedEyebrow => eyebrow?.trim() ?? '';
  bool get _hasBrandImage => (brandImageUrl ?? '').isNotEmpty;
}

class HeroSlidePreview extends StatelessWidget {
  const HeroSlidePreview({super.key, required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: _routeFor(data),
    );
  }

  Widget _routeFor(HeroSlidePreviewData d) {
    switch (d.template) {
      case BannerTemplate.imageOnly:
        return _ImageOnlyCard(data: d);
      case BannerTemplate.minimal:
        return _MinimalCard(data: d);
      case BannerTemplate.split:
        return _SplitCard(data: d);
      case BannerTemplate.overlay:
        return _OverlayCard(data: d);
      case BannerTemplate.deal:
        return _DealCard(data: d);
      case BannerTemplate.poster:
        return _PosterCard(data: d);
      case BannerTemplate.classic:
        return _ClassicCard(data: d);
    }
  }
}

// ─── Shared visual helpers ──────────────────────────────────────────

Color _autoFg(Color bg) =>
    bg.computeLuminance() > 0.55 ? AppColors.black : AppColors.white;

Color _shade(Color base, double amount) {
  final r = (base.r * 255 * (1 - amount)).round();
  final g = (base.g * 255 * (1 - amount)).round();
  final b = (base.b * 255 * (1 - amount)).round();
  return Color.fromARGB(
    (base.a * 255).round(),
    r.clamp(0, 255),
    g.clamp(0, 255),
    b.clamp(0, 255),
  );
}

LinearGradient _panelGradient(Color base) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [base, _shade(base, 0.08)],
    );

final List<BoxShadow> _kCardShadows = [
  BoxShadow(
    color: AppColors.black.withValues(alpha: 0.08),
    blurRadius: 18,
    offset: const Offset(0, 8),
  ),
  BoxShadow(
    color: AppColors.black.withValues(alpha: 0.04),
    blurRadius: 4,
    offset: const Offset(0, 1),
  ),
];

class _SlideFrame extends StatelessWidget {
  const _SlideFrame({
    required this.bgColor,
    required this.child,
    this.useGradient = true,
  });
  final Color bgColor;
  final Widget child;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: useGradient ? null : bgColor,
        gradient: useGradient ? _panelGradient(bgColor) : null,
        shape: AppShapes.squircle(AppSizes.radiusLg),
        shadows: _kCardShadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Network image with an in-frame placeholder when url is empty or
/// while loading. Matches the customer's NetworkImageBox behaviour.
class _Image extends StatelessWidget {
  const _Image({
    required this.url,
    required this.placeholderColor,
    this.fit = BoxFit.cover,
  });
  final String? url;
  final Color placeholderColor;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) {
      return Container(color: placeholderColor);
    }
    // Paint the bg behind the image so BoxFit.contain letterboxes
    // onto the chosen slide colour instead of a transparent strip.
    return Container(
      color: placeholderColor,
      child: Image.network(
        resolveImageUrl(u),
        fit: fit,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Renders the brand mark on a templated card. Three modes:
///   * logo only — when only `brandImageUrl` is set
///   * label only — when only `brandLabel` is set (caller's chip)
///   * logo + label — when BOTH are set (logo circle on the left, the
///     template's existing label chip on the right, with a small gap)
///
/// Returns `SizedBox.shrink()` when neither is present so callers can
/// emit `_BrandMark(...)` unconditionally without `if` guards.
///
/// `centerInRow: true` switches the row layout to centred alignment
/// for templates like Overlay where the whole content stack is centred.
class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.data,
    required this.fallbackBuilder,
    this.size = 28,
    this.centerInRow = false,
  });
  final HeroSlidePreviewData data;
  /// Renders the text chip when the slide has a brand label. Each
  /// template has its own treatment (pill on Classic, uppercase
  /// tracked on Minimal, etc.) so the caller passes a builder.
  final Widget Function(BuildContext) fallbackBuilder;
  /// Diameter of the circular logo crop.
  final double size;
  /// Set true for Overlay-style centred templates so the logo+label
  /// row sits centred horizontally instead of left-aligned.
  final bool centerInRow;

  @override
  Widget build(BuildContext context) {
    final hasImage = data._hasBrandImage;
    final hasLabel = data._resolvedBrand.isNotEmpty;
    if (!hasImage && !hasLabel) return const SizedBox.shrink();

    final logo = hasImage
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              resolveImageUrl(data.brandImageUrl!),
              fit: data.brandImageFit == BannerImageFit.contain
                  ? BoxFit.contain
                  : BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          )
        : null;

    final label = hasLabel ? fallbackBuilder(context) : null;

    if (logo != null && label != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            centerInRow ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          logo,
          const SizedBox(width: AppSizes.sm),
          Flexible(child: label),
        ],
      );
    }
    return logo ?? label!;
  }
}

class _PillCta extends StatelessWidget {
  const _PillCta({
    required this.label,
    required this.bg,
    required this.fg,
  });
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
        shadows: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _ShimmerPill extends StatefulWidget {
  const _ShimmerPill({
    required this.label,
    required this.bg,
    required this.fg,
  });
  final String label;
  final Color bg;
  final Color fg;

  @override
  State<_ShimmerPill> createState() => _ShimmerPillState();
}

class _ShimmerPillState extends State<_ShimmerPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppDurations.snackbarLong,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Stack(
        children: [
          _PillCta(label: widget.label, bg: widget.bg, fg: widget.fg),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) {
                  final t = -1.4 + _ctrl.value * 2.8;
                  return FractionalTranslation(
                    translation: Offset(t, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-1, 0),
                          end: const Alignment(1, 0),
                          colors: [
                            Colors.transparent,
                            AppColors.white.withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                          stops: const [0.35, 0.5, 0.65],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowPulse extends StatefulWidget {
  const _GlowPulse({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  State<_GlowPulse> createState() => _GlowPulseState();
}

class _GlowPulseState extends State<_GlowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25 + t * 0.35),
                blurRadius: 16 + t * 12,
                spreadRadius: t * 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _KenBurns extends StatefulWidget {
  const _KenBurns({required this.child});
  final Widget child;

  @override
  State<_KenBurns> createState() => _KenBurnsState();
}

class _KenBurnsState extends State<_KenBurns>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final scale = 1.0 + Curves.easeInOut.transform(_ctrl.value) * 0.06;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

class _CornerVignette extends StatelessWidget {
  const _CornerVignette();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [
                Colors.transparent,
                Colors.transparent,
                AppColors.black.withValues(alpha: 0.18),
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _DealBadge extends StatelessWidget {
  const _DealBadge({required this.text, required this.accent});
  final String text;
  final Color accent;

  ({String number, String suffix})? _split() {
    final m = RegExp(r'(\d+%?)').firstMatch(text);
    if (m == null) return null;
    final number = m.group(1)!;
    var suffix = text.substring(m.end).trim();
    if (suffix.isEmpty) suffix = 'OFF';
    return (number: number, suffix: suffix);
  }

  @override
  Widget build(BuildContext context) {
    final parts = _split();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, _shade(accent, 0.22)],
        ),
        shape: AppShapes.squircle(AppSizes.radiusMd),
        shadows: [
          BoxShadow(
            color: accent.withValues(alpha: 0.50),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: parts == null
          ? Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    height: 1.0,
                  ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  parts.number,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.suffix.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        height: 1.0,
                      ),
                ),
              ],
            ),
    );
  }
}

// ─── 7 card variants — 1:1 port of the customer renderer ───────────

class _ClassicCard extends StatelessWidget {
  const _ClassicCard({required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      // StackFit.expand pins the Stack to the parent constraints so
      // we don't need a non-positioned intrinsic-sized child. The
      // Row+Expanded+Spacer body never gets intrinsic-queried (the
      // _debugDoingThisLayout crash) because non-positioned children
      // receive tight constraints under StackFit.expand.
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Right-anchored image. FractionallySizedBox keeps the image
          // at 62% of the card width so Classic scales the same way as
          // the other right-image templates (Deal, Split) — the
          // previous hardcoded 220 px made the image look bigger on
          // narrow cards and smaller on wide ones.
          Positioned.fill(
            left: null,
            right: 0,
            child: FractionallySizedBox(
              widthFactor: 0.62,
              alignment: Alignment.centerRight,
              child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    data.bgColor,
                    data.bgColor.withValues(alpha: 0.95),
                    data.bgColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.32, 0.55, 0.95],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BrandMark(
                  data: data,
                  fallbackBuilder: (_) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: 3,
                    ),
                    decoration: ShapeDecoration(
                      color: data.accent,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                      shadows: [
                        BoxShadow(
                          color: data.accent.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      brand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                if (eyebrow.isNotEmpty) ...[
                  Text(
                    eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: fg.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: fg.withValues(alpha: 0.78),
                          height: 1.3,
                        ),
                  ),
                ],
                const SizedBox(height: AppSizes.sm),
                _ShimmerPill(
                  label: data._resolvedCta,
                  bg: AppColors.black,
                  fg: AppColors.white,
                ),
              ],
                  ),
                ),
                const Spacer(flex: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalCard extends StatelessWidget {
  const _MinimalCard({required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BrandMark(
                    data: data,
                    size: 24,
                    fallbackBuilder: (_) => Text(
                      brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: data.accent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                    ),
                  ),
                  if (eyebrow.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      eyebrow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: fg.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -0.6,
                        ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.65),
                            height: 1.3,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  // Same CTA pill shape as the other templates so the
                  // merchant's "Button label" field actually drives what
                  // they see on every card. Previously this was a
                  // hardcoded "Explore" text + arrow, which silently
                  // ignored the editor field.
                  _PillCta(
                    label: data._resolvedCta,
                    bg: data.accent,
                    fg: AppColors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            // Square circular medallion sized off the card height so
            // it scales together with the parent. AspectRatio keeps it
            // a perfect circle regardless of card width.
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.4, -0.5),
                            radius: 0.95,
                            colors: [
                              AppColors.white.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageOnlyCard extends StatelessWidget {
  const _ImageOnlyCard({required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    return _SlideFrame(
      bgColor: data.bgColor,
      useGradient: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: _KenBurns(
              child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
            ),
          ),
          const _CornerVignette(),
        ],
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      useGradient: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _panelGradient(data.bgColor)),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BrandMark(
                        data: data,
                        size: 24,
                        fallbackBuilder: (_) => Text(
                          brand.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: data.accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                        ),
                      ),
                      if (eyebrow.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: fg.withValues(alpha: 0.6),
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  letterSpacing: -0.5,
                                ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: fg.withValues(alpha: 0.8),
                                  ),
                        ),
                      ],
                      const SizedBox(height: AppSizes.sm),
                      _ShimmerPill(
                        label: data._resolvedCta,
                        bg: data.accent,
                        fg: AppColors.white,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _Image(
                        url: data.imageUrl,
                        placeholderColor: data.bgColor,
                        fit: data.boxFit,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              data.bgColor.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      useGradient: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: _KenBurns(
              child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    AppColors.black.withValues(alpha: 0.50),
                    AppColors.black.withValues(alpha: 0.20),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _BrandMark(
                  data: data,
                  size: 26,
                  centerInRow: true,
                  fallbackBuilder: (_) => Text(
                    brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                  ),
                ),
                if (eyebrow.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    eyebrow,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.88),
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: AppColors.black.withValues(alpha: 0.4),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.92),
                        ),
                  ),
                ],
                const SizedBox(height: AppSizes.xs),
                _ShimmerPill(
                  label: data._resolvedCta,
                  bg: AppColors.white,
                  fg: AppColors.black,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final dealText = brand.isEmpty ? 'DEAL' : brand.toUpperCase();
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Right-anchored image. Same widthFactor as Classic so the
          // right-image templates render at a consistent visual size
          // regardless of card width.
          Positioned.fill(
            left: null,
            right: 0,
            child: FractionallySizedBox(
              widthFactor: 0.62,
              alignment: Alignment.centerRight,
              child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    data.bgColor,
                    data.bgColor.withValues(alpha: 0.0),
                  ],
                  stops: const [0.4, 0.85],
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSizes.lg,
            left: AppSizes.lg,
            child: _GlowPulse(
              color: data.accent,
              child: _DealBadge(text: dealText, accent: data.accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (eyebrow.isNotEmpty) ...[
                        Text(
                          eyebrow,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: fg.withValues(alpha: 0.72),
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: fg,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  letterSpacing: -0.5,
                                ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: fg.withValues(alpha: 0.8),
                                  ),
                        ),
                      ],
                      const SizedBox(height: AppSizes.sm),
                      _PillCta(
                        label: data._resolvedCta,
                        bg: data.accent,
                        fg: AppColors.white,
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.data});
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      useGradient: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _Image(
                    url: data.imageUrl,
                    placeholderColor: data.bgColor,
                    fit: data.boxFit,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          data.bgColor.withValues(alpha: 0.55),
                        ],
                        stops: const [0.65, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: _panelGradient(data.bgColor),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BrandMark(
                          data: data,
                          size: 22,
                          fallbackBuilder: (_) => Text(
                            brand.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: data.accent,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                          ),
                        ),
                        if (eyebrow.isNotEmpty)
                          Text(
                            eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: fg.withValues(alpha: 0.6),
                                      fontStyle: FontStyle.italic,
                                    ),
                          ),
                        Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: fg,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                    letterSpacing: -0.4,
                                  ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: fg.withValues(alpha: 0.7),
                                    ),
                          ),
                      ],
                    ),
                  ),
                  // Same pill CTA shape as the other templates instead
                  // of the arrow-only icon — the merchant's button label
                  // now reads consistently across all 6 text-bearing
                  // templates.
                  _PillCta(
                    label: data._resolvedCta,
                    bg: data.accent,
                    fg: AppColors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
