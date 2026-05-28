import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Customer-side template renderer for HERO carousel slides. Ports the
/// 6 + 1 visual card classes from the merchant editor preview verbatim
/// (per the project's "duplicate, don't extract" rule for shared
/// customer/merchant code) so what the merchant sees in the editor is
/// exactly what the customer renders here.
///
/// One entry point: `HeroSlideTemplateRenderer(slide: ...)` dispatches
/// on `slide.template` to the matching card. Sized fixed at 188 to fit
/// the existing customer hero PageView; the merchant editor uses a
/// taller preview (210) but the card layouts scale within the slot.

/// Local helper accessors so the existing port can treat the customer
/// `HeroSlide` exactly the way the merchant's `HeroSlidePreviewData`
/// was treated. Keeps the body of every card class unchanged from the
/// merchant version (easier to diff and keep in sync).
extension _SlideAccessors on HeroSlide {
  BoxFit get boxFit => imageFit.boxFit;

  String get _resolvedCta {
    final t = ctaText?.trim();
    return (t == null || t.isEmpty) ? 'Shop now' : t;
  }

  String get _resolvedBrand => brand.trim();
  String get _resolvedSubtitle => subtitle.trim();
  String get _resolvedEyebrow => eyebrow?.trim() ?? '';
  bool get _hasBrandImage => (brandImageUrl ?? '').isNotEmpty;
}

class HeroSlideTemplateRenderer extends StatelessWidget {
  const HeroSlideTemplateRenderer({super.key, required this.slide});
  final HeroSlide slide;

  /// Width-to-height ratio for templated banner cards. 16:10 matches
  /// the proportions the merchant editor previews and gives each
  /// template enough vertical room for two-line titles + an eyebrow +
  /// a CTA pill without overflowing. The renderer needs a bounded
  /// height (Stack templates use `Positioned.fill`), so we derive it
  /// from the parent's width rather than hard-coding a fixed pixel
  /// value that breaks on narrow / wide devices.
  static const double aspectRatio = 16 / 10;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: _routeFor(slide),
    );
  }

  Widget _routeFor(HeroSlide d) {
    switch (d.template) {
      case HeroSlideTemplate.imageOnly:
        return _ImageOnlyCard(data: d);
      case HeroSlideTemplate.minimal:
        return _MinimalCard(data: d);
      case HeroSlideTemplate.split:
        return _SplitCard(data: d);
      case HeroSlideTemplate.overlay:
        return _OverlayCard(data: d);
      case HeroSlideTemplate.deal:
        return _DealCard(data: d);
      case HeroSlideTemplate.poster:
        return _PosterCard(data: d);
      case HeroSlideTemplate.classic:
        return _ClassicCard(data: d);
    }
  }
}

// ─── Shared visual helpers ──────────────────────────────────────────

Color _autoFg(Color bg) =>
    bg.computeLuminance() > 0.55 ? AppColors.black : Colors.white;

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

const List<BoxShadow> _kCardShadows = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  ),
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 4,
    offset: Offset(0, 1),
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

/// Render the brand mark on a templated card. Logo + label show
/// together when both are set; either alone otherwise. Mirrors the
/// merchant-side `_BrandMark` exactly (per the project's "duplicate,
/// don't extract" rule for shared customer/merchant code).
class _BrandMark extends StatelessWidget {
  const _BrandMark({
    required this.data,
    required this.fallbackBuilder,
    this.size = 28,
    this.centerInRow = false,
  });
  final HeroSlide data;
  final Widget Function(BuildContext) fallbackBuilder;
  final double size;
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              resolveImageUrl(data.brandImageUrl!),
              fit: data.brandImageFit.boxFit,
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
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
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
      duration: const Duration(milliseconds: 5000),
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
                            Colors.white.withValues(alpha: 0.35),
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
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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
                Colors.black.withValues(alpha: 0.18),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.suffix.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
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
  final HeroSlide data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      // StackFit.expand pins the Stack to parent constraints so we
      // don't need a non-positioned intrinsic-sized child to give it
      // dimensions. Without this the Stack would collapse to 0×0 in
      // the customer's PageView (loose width) and nothing would render.
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Right-anchored image at a fraction of card width. Wrapping
          // the FractionallySizedBox in an Align inside a proper
          // Positioned.fill gives it bounded constraints — the older
          // `left: null, right: 0` form left width unbounded and crashed
          // any time Classic was rendered outside a PageView slot.
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.62,
                heightFactor: 1.0,
                child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
              ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
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
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.72),
                      fontSize: 10,
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
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
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
                    style: TextStyle(
                      color: fg.withValues(alpha: 0.78),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.sm),
                _ShimmerPill(
                  label: data._resolvedCta,
                  bg: AppColors.black,
                  fg: Colors.white,
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
  final HeroSlide data;

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
                      style: TextStyle(
                        color: data.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
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
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
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
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.65),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  _PillCta(
                    label: data._resolvedCta,
                    bg: data.accent,
                    fg: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            // Square circular medallion sized off card height so it
            // scales together with the parent — no more fixed 140 px.
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
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
                              Colors.white.withValues(alpha: 0.18),
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
  final HeroSlide data;

  @override
  Widget build(BuildContext context) {
    return _SlideFrame(
      bgColor: data.bgColor,
      useGradient: false,
      // StackFit.expand: all children are Positioned.fill, so without
      // expand the Stack would collapse to 0×0 and the slide would
      // render as a zero-width strip.
      child: Stack(
        fit: StackFit.expand,
        children: [
          _KenBurns(
            child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
          ),
          const _CornerVignette(),
        ],
      ),
    );
  }
}

class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.data});
  final HeroSlide data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      useGradient: false,
      // StackFit.expand pins the Stack to the slide-frame constraints;
      // without it the Stack would size to the Row's intrinsic width
      // when the Row's bounded behaviour fails on loose constraints.
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: _panelGradient(data.bgColor)),
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
                          style: TextStyle(
                            color: data.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
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
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.6),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
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
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSizes.sm),
                      _ShimmerPill(
                        label: data._resolvedCta,
                        bg: data.accent,
                        fg: Colors.white,
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
  final HeroSlide data;

  @override
  Widget build(BuildContext context) {
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    final eyebrow = data._resolvedEyebrow;
    return _SlideFrame(
      bgColor: data.bgColor,
      useGradient: false,
      // StackFit.expand: without it, the lone non-positioned child
      // (the centered Padding/Column with MainAxisSize.min) sizes the
      // Stack to its text intrinsic width — collapsing the whole slide
      // to ~250 px regardless of the page slot.
      child: Stack(
        fit: StackFit.expand,
        children: [
          _KenBurns(
            child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: [
                  Colors.black.withValues(alpha: 0.50),
                  Colors.black.withValues(alpha: 0.20),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0.55, 1.0],
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 11,
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
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    height: 1.05,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
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
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.xs),
                _ShimmerPill(
                  label: data._resolvedCta,
                  bg: Colors.white,
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
  final HeroSlide data;

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
          // Right-anchored image at the same fractional width as
          // Classic so the two right-image templates render with
          // matching proportions. See _ClassicCard for the rationale
          // behind Align + Positioned.fill over `left: null, right: 0`.
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.62,
                heightFactor: 1.0,
                child: _Image(url: data.imageUrl, placeholderColor: data.bgColor, fit: data.boxFit),
              ),
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
            top: 16,
            left: 16,
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
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.72),
                            fontSize: 10,
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
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
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
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSizes.sm),
                      _PillCta(
                        label: data._resolvedCta,
                        bg: data.accent,
                        fg: Colors.white,
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
  final HeroSlide data;

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
                            style: TextStyle(
                              color: data.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (eyebrow.isNotEmpty)
                          Text(
                            eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.6),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        Text(
                          data.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            height: 1.05,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _PillCta(
                    label: data._resolvedCta,
                    bg: data.accent,
                    fg: Colors.white,
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
