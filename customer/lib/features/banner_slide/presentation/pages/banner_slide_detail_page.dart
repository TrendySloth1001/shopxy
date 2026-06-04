import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/banner_slide/data/datasources/banner_slide_remote_data_source.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shadows.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Customer-facing detail page for a single carousel slide. Hits
/// /banners/:id/slide and renders the merchant's curated product list
/// with per-row percent-off badges and a computed sale price next to
/// the struck-through selling price.
///
/// Visual structure:
///   1. Collapsing parallax hero (banner image as backdrop, content
///      overlaid with a vertical gradient for legibility).
///   2. Pinned "deal strip" — max discount, product count, FREE
///      DELIVERY-style trust chips. Stays visible while scrolling.
///   3. 2-column product grid with shadowed cards, discount chip,
///      sale + struck-through price, and a "You save" pill.
///
/// Sale price is **display-only**. Tapping a card pushes the canonical
/// product-detail page; the cart still charges sellingPrice.
class BannerSlideDetailPage extends StatefulWidget {
  const BannerSlideDetailPage({super.key, required this.bannerId});
  final int bannerId;

  @override
  State<BannerSlideDetailPage> createState() => _BannerSlideDetailPageState();
}

class _BannerSlideDetailPageState extends State<BannerSlideDetailPage> {
  late final BannerSlideRemoteDataSource _ds;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _slide;

  @override
  void initState() {
    super.initState();
    _ds = context.read<BannerSlideRemoteDataSource>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ds.fetch(widget.bannerId);
      if (!mounted) return;
      setState(() {
        _slide = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Hero is dark-ish — keep status-bar icons light until the user
      // scrolls past it. The pinned SliverAppBar handles the swap by
      // turning opaque, which the system status overlay also picks up.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: _loading
            ? const _SlideSkeleton()
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _load)
                : _slide == null
                    ? const _MissingView()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _Body(slide: _slide!),
                      ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.slide});
  final Map<String, dynamic> slide;

  @override
  Widget build(BuildContext context) {
    final banner = slide['banner'] as Map<String, dynamic>;
    final products = (slide['products'] as List?) ?? const [];
    final bg = _parseColor(
      banner['bgColor'] as String?,
      fallback: AppColors.heroPanel,
    );

    // "Best price" headline = the slide's highest discount %. Gives the
    // customer a one-glance reason to keep scrolling.
    final maxDiscount = products.fold<int>(
      0,
      (m, raw) {
        final v = (raw as Map<String, dynamic>)['discountPct'];
        final n = v is num ? v.toInt() : 0;
        return n > m ? n : m;
      },
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        _HeroSliver(banner: banner, bg: bg, productCount: products.length),
        SliverToBoxAdapter(
          child: _DealStrip(
            productCount: products.length,
            maxDiscount: maxDiscount,
          ),
        ),
        if (products.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyProducts(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.huge,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSizes.lg,
                crossAxisSpacing: AppSizes.lg,
                childAspectRatio: 0.56,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) =>
                    _ProductCard(raw: products[i] as Map<String, dynamic>),
                childCount: products.length,
              ),
            ),
          ),
      ],
    );
  }
}

Color _parseColor(String? hex, {required Color fallback}) {
  if (hex == null) return fallback;
  final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
  if (m == null) return fallback;
  var raw = m.group(1)!;
  if (raw.length == 6) raw = 'FF$raw';
  return Color(int.parse(raw, radix: 16));
}

/// Collapsing hero. Image bleeds full-bleed behind the title, dimmed
/// with a top-to-bottom dark gradient so the brand badge / title / CTA
/// always read. We let `FlexibleSpaceBar` handle the parallax + fade
/// (stretch + fadeTitle) instead of reaching into its inherited
/// settings — the manual peek breaks in some Material releases when
/// the bar is mid-collapse.
class _HeroSliver extends StatelessWidget {
  const _HeroSliver({
    required this.banner,
    required this.bg,
    required this.productCount,
  });
  final Map<String, dynamic> banner;
  final Color bg;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final image = (banner['imageUrl'] ?? '') as String;
    final title = (banner['title'] ?? '') as String;
    final subtitle = (banner['subtitle'] ?? '') as String;
    final brand = (banner['brandLabel'] ?? banner['eyebrow'] ?? '') as String;
    final ctaText = (banner['ctaText'] ?? '') as String;
    final accent = _parseColor(
      banner['accentColor'] as String?,
      fallback: AppColors.brand,
    );

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.canvas,
      foregroundColor: AppColors.black,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: const _CircleBackButton(),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.black,
            ),
      ),
      titleSpacing: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.fadeTitle,
        ],
        // Hero content lives in `background` — `title` is intentionally
        // empty so we don't double-render against the SliverAppBar's
        // own collapsed `title`.
        title: const SizedBox.shrink(),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: bg),
            if (image.isNotEmpty)
              NetworkImageBox(
                url: resolveImageUrl(image),
                placeholderColor: bg,
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.black.withValues(alpha: 0.22),
                      AppColors.black.withValues(alpha: 0.05),
                      AppColors.black.withValues(alpha: 0.78),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // Hero copy anchored to the bottom-left. As the bar
            // collapses, FlexibleSpaceBar's `fadeTitle` stretch mode
            // fades the whole background, so the copy crossfades into
            // the pinned toolbar title without any manual tracking.
            Positioned(
              left: AppSizes.lg,
              right: AppSizes.lg,
              bottom: AppSizes.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (brand.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: AppSizes.xs,
                      ),
                      decoration: ShapeDecoration(
                        color: accent,
                        shape: AppShapes.squircle(AppSizes.radiusSm),
                      ),
                      child: Text(
                        brand.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                      ),
                    ),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: AppColors.black.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.white,
                            height: 1.3,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.md),
                  Row(
                    children: [
                      if (ctaText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: AppSizes.sm,
                          ),
                          decoration: ShapeDecoration(
                            color: AppColors.white,
                            shape: AppShapes.squircle(AppSizes.radiusFull),
                          ),
                          child: Text(
                            ctaText,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.black,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      const Spacer(),
                      if (productCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.sm,
                            vertical: AppSizes.xs,
                          ),
                          decoration: ShapeDecoration(
                            color: AppColors.black.withValues(alpha: 0.35),
                            shape: AppShapes.squircle(AppSizes.radiusFull),
                          ),
                          child: Text(
                            '$productCount ITEMS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deal strip — sits flush under the hero with the headline discount,
/// product count, and trust chips. Sized to its content (no pinned
/// persistent-header gymnastics that fight overscroll physics).
class _DealStrip extends StatelessWidget {
  const _DealStrip({
    required this.productCount,
    required this.maxDiscount,
  });
  final int productCount;
  final int maxDiscount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          if (maxDiscount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: ShapeDecoration(
                color: AppColors.brand,
                shape: AppShapes.squircle(AppSizes.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_offer_rounded,
                    color: AppColors.white,
                    size: AppSizes.iconSm,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    'Up to $maxDiscount% OFF',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                  ),
                ],
              ),
            )
          else if (productCount > 0)
            Text(
              '$productCount curated picks',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          const Spacer(),
          const _TrustChip(
            icon: Icons.local_shipping_outlined,
            label: 'Free delivery',
          ),
          const SizedBox(width: AppSizes.xs),
          const _TrustChip(
            icon: Icons.verified_user_outlined,
            label: 'Genuine',
          ),
        ],
      ),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: AppColors.surfaceTint,
        shape: AppShapes.squircle(
          AppSizes.radiusFull,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: AppColors.muted),
          const SizedBox(width: AppSizes.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Rounded back affordance that floats over the hero. Same chrome
/// Flipkart / Myntra use — keeps the back arrow legible on a busy
/// banner image.
class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSizes.sm,
        top: AppSizes.xs,
        bottom: AppSizes.xs,
      ),
      child: Material(
        color: AppColors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: const SizedBox(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            child: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.white,
              size: AppSizes.iconMd,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.raw});
  final Map<String, dynamic> raw;

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final id = (raw['id'] as num).toInt();
    final name = (raw['name'] ?? '') as String;
    final selling = _asDouble(raw['sellingPrice']);
    final mrp = _asDouble(raw['mrp']);
    final salePrice = _asDouble(raw['salePrice']);
    final discountPct = (raw['discountPct'] as num?)?.toInt() ?? 0;
    final ratingAvg = _asDouble(raw['ratingAvg']);
    final ratingCount = (raw['ratingCount'] as num?)?.toInt() ?? 0;
    final images = (raw['images'] as List?) ?? const [];
    final image = images.isNotEmpty
        ? (images.first as Map<String, dynamic>)['url'] as String? ?? ''
        : '';

    final priceShown = discountPct > 0 ? salePrice : selling;
    final priceCrossed = discountPct > 0 ? selling : mrp;
    final saves = (priceCrossed - priceShown).clamp(0, double.infinity);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
        boxShadow: AppShadows.floating,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(productId: id),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: AppShapes.squircleTopRadius(
                          AppSizes.radiusMd,
                        ),
                        child: image.isEmpty
                            ? Container(color: AppColors.heroPanel)
                            : NetworkImageBox(url: resolveImageUrl(image)),
                      ),
                    ),
                    if (discountPct > 0)
                      Positioned(
                        top: AppSizes.sm,
                        left: AppSizes.sm,
                        child: _DiscountChip(percent: discountPct),
                      ),
                    Positioned(
                      bottom: AppSizes.sm,
                      right: AppSizes.sm,
                      child: _WishlistFab(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.sm,
                  AppSizes.sm,
                  AppSizes.sm,
                  AppSizes.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                    ),
                    if (ratingCount > 0) ...[
                      const SizedBox(height: AppSizes.xs),
                      _RatingPill(rating: ratingAvg, count: ratingCount),
                    ],
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${priceShown.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                        ),
                        if (priceCrossed > priceShown) ...[
                          const SizedBox(width: AppSizes.sm),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              '₹${priceCrossed.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (saves > 0) ...[
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        'You save ₹${saves.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountChip extends StatelessWidget {
  const _DiscountChip({required this.percent});
  final int percent;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandStrong],
        ),
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$percent% OFF',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

class _WishlistFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.xxxl,
      height: AppSizes.xxxl,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        boxShadow: AppShadows.floating,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.favorite_border_rounded,
        size: AppSizes.iconSm,
        color: AppColors.muted,
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  const _RatingPill({required this.rating, required this.count});
  final double rating;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: AppColors.success,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: AppSizes.xs),
          const Icon(
            Icons.star_rounded,
            color: AppColors.white,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSizes.xs),
          Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_offer_outlined,
              size: AppSizes.iconHuge,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              'No products in this drop yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'The shop is curating this slide — check back soon.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First-paint placeholder — shaped blocks that mirror the real layout
/// so the transition from skeleton → real content stays stable.
class _SlideSkeleton extends StatelessWidget {
  const _SlideSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget block({
      double? width,
      double height = AppSizes.lg,
      double radius = AppSizes.radiusSm,
    }) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.heroPanel,
            borderRadius: AppShapes.squircleRadius(radius),
          ),
        );
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 320,
          child: Container(color: AppColors.heroPanel),
        ),
        const SizedBox(height: AppSizes.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: block(
            height: AppSizes.xxl,
            width: 140,
            radius: AppSizes.radiusButton,
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSizes.lg,
              crossAxisSpacing: AppSizes.lg,
              childAspectRatio: 0.56,
            ),
            itemBuilder: (_, _) => Container(
              decoration: BoxDecoration(
                color: AppColors.heroPanel,
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: AppSizes.iconHuge,
                color: AppColors.muted,
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                "Couldn't load this slide",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
              const SizedBox(height: AppSizes.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingView extends StatelessWidget {
  const _MissingView();
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Text(
            'This slide has ended or is no longer available.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
        ),
      ),
    );
  }
}
