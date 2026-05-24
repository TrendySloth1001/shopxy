import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_models.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_v2_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// The V2 deals screen. Was a static mock with hardcoded "GRWM SALE"
/// / "WEDDING EDIT" / "GLOW-UP SALE" stories and a fake countdown
/// timer until this build — now reads from [HomeFeedProvider]
/// (flashDeals + brandSpotlights), shows the live countdown derived
/// from the earliest sale endAt, and routes taps to the real PDP /
/// shop profile pages.
///
/// Sample-only sections (cross-brand coupons, bank-partner offers,
/// "shop by category" chips) collapse when there's no corresponding
/// backend data yet, rather than showing fake content.
class DealsV2Page extends StatefulWidget {
  const DealsV2Page({super.key});

  @override
  State<DealsV2Page> createState() => _DealsV2PageState();
}

class _DealsV2PageState extends State<DealsV2Page> {
  Timer? _ticker;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final earliest = _earliestEndAt(context.read<HomeFeedProvider>());
      setState(() {
        _remaining = earliest?.difference(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime? _earliestEndAt(HomeFeedProvider p) {
    final deals = p.feed.flashDeals;
    if (deals.isEmpty) return null;
    return deals
        .map((d) => d.endAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<HomeFeedProvider>();
    final flashDeals = feed.feed.flashDeals;
    final spotlights = feed.feed.brandSpotlights;
    final earliest = _earliestEndAt(feed);
    final remaining = _remaining ?? earliest?.difference(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        title: const Text('Deals'),
      ),
      body: RefreshIndicator(
        onRefresh: () => feed.refresh(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSizes.huge),
          children: [
            if (flashDeals.isNotEmpty)
              _FlashHeader(remaining: remaining == null ? null : _fmt(remaining)),
            if (flashDeals.isEmpty && spotlights.isEmpty)
              const _Empty()
            else ...[
              if (flashDeals.isNotEmpty) _FlashGrid(deals: flashDeals),
              if (spotlights.isNotEmpty) _Spotlights(brands: spotlights),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlashHeader extends StatelessWidget {
  const _FlashHeader({required this.remaining});
  final String? remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: const Color(0xFFFFE3D2),
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, color: Color(0xFFE05A2A), size: 22),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Text(
              'Flash deals — ending soon',
              style: TextStyle(
                color: Color(0xFFE05A2A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (remaining != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                remaining!,
                style: const TextStyle(
                  color: Color(0xFFE05A2A),
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FlashGrid extends StatelessWidget {
  const _FlashGrid({required this.deals});
  final List<FlashDealProduct> deals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: deals.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSizes.md,
          crossAxisSpacing: AppSizes.md,
          childAspectRatio: 0.62,
        ),
        itemBuilder: (_, i) => _FlashTile(deal: deals[i]),
      ),
    );
  }
}

class _FlashTile extends StatelessWidget {
  const _FlashTile({required this.deal});
  final FlashDealProduct deal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailV2Page(productId: deal.productId),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              child: Container(
                color: AppColors.heroPanel,
                child: deal.imageUrl.isEmpty
                    ? const Icon(Icons.image_outlined, color: AppColors.muted)
                    : NetworkImageBox(url: resolveImageUrl(deal.imageUrl)),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            deal.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                deal.price,
                style: const TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              if (deal.originalPrice.isNotEmpty)
                Text(
                  deal.originalPrice,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                '${deal.discountPct}% off',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: deal.soldPct,
              minHeight: 5,
              backgroundColor: AppColors.hairline,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFE05A2A)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${(deal.soldPct * 100).round()}% claimed',
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Spotlights extends StatelessWidget {
  const _Spotlights({required this.brands});
  final List<BrandSpotlight> brands;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.xl, AppSizes.lg, AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Brands in spotlight',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: AppSizes.md),
          for (final b in brands) ...[
            _SpotlightTile(brand: b),
            const SizedBox(height: AppSizes.md),
          ],
        ],
      ),
    );
  }
}

class _SpotlightTile extends StatelessWidget {
  const _SpotlightTile({required this.brand});
  final BrandSpotlight brand;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: brand.shopSlug == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShopProfilePage(slug: brand.shopSlug!),
                ),
              ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (brand.imageUrl.isNotEmpty)
                NetworkImageBox(
                  url: resolveImageUrl(brand.imageUrl),
                  placeholderColor: brand.bgColor,
                )
              else
                Container(color: brand.bgColor),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F757),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        brand.dealLabel,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      brand.brand,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    if (brand.subtitle.isNotEmpty)
                      Text(
                        brand.subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(AppSizes.xl, AppSizes.huge, AppSizes.xl, 0),
      child: Column(
        children: [
          Icon(Icons.bolt_outlined, color: AppColors.muted, size: 48),
          SizedBox(height: AppSizes.sm),
          Text(
            'No deals running right now',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          SizedBox(height: 4),
          Text(
            'Pull to refresh — flash sales drop without notice.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
