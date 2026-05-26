import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
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
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
    return _SlideFrame(
      bgColor: data.bgColor,
      child: Stack(
        children: [
          Positioned.fill(
            left: null,
            right: 0,
            child: SizedBox(
              width: 220,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (brand.isNotEmpty)
                  Container(
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
                const SizedBox(height: AppSizes.sm),
                SizedBox(
                  width: 200,
                  child: Text(
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
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 200,
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.3,
                      ),
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
                  if (brand.isNotEmpty)
                    Text(
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Explore',
                        style: TextStyle(
                          color: data.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: data.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Container(
              width: 140,
              height: 140,
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
                      if (brand.isNotEmpty)
                        Text(
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
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final brand = data._resolvedBrand;
    final subtitle = data._resolvedSubtitle;
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
                    Colors.black.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.20),
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
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (brand.isNotEmpty)
                  Text(
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
                const SizedBox(height: 6),
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    height: 1.0,
                    letterSpacing: -0.8,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.sm),
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
  final HeroSlidePreviewData data;

  @override
  Widget build(BuildContext context) {
    final fg = _autoFg(data.bgColor);
    final brand = data._resolvedBrand;
    final dealText = brand.isEmpty ? 'DEAL' : brand.toUpperCase();
    final subtitle = data._resolvedSubtitle;
    return _SlideFrame(
      bgColor: data.bgColor,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 10,
            bottom: 10,
            child: SizedBox(
              width: 200,
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
            top: 16,
            left: 16,
            child: _GlowPulse(
              color: data.accent,
              child: _DealBadge(text: dealText, accent: data.accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
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
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 200,
                    child: Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
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
                        if (brand.isNotEmpty)
                          Text(
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: 8,
                    ),
                    decoration: ShapeDecoration(
                      color: data.accent,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                      shadows: [
                        BoxShadow(
                          color: data.accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
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
