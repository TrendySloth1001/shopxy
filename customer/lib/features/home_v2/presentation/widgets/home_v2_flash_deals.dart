import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_models.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_v2_page.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeV2FlashDeals extends StatefulWidget {
  const HomeV2FlashDeals({super.key, required this.deals});
  final List<FlashDealProduct> deals;

  @override
  State<HomeV2FlashDeals> createState() => _HomeV2FlashDealsState();
}

class _HomeV2FlashDealsState extends State<HomeV2FlashDeals> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HomeV2FlashDeals oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The countdown is derived from each card's `endAt`. If the parent
    // hands us a different deals list (different identities, or even a
    // reordered list), kick the timer so we don't end up counting
    // against a stale snapshot if the previous one had been paused
    // mid-frame.
    if (!listEquals(oldWidget.deals, widget.deals)) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    // Single global tick — the countdown labels for each card derive
    // from their own `endAt`. One repaint per second is enough; no
    // need for per-card timers.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  /// Picks the shortest remaining window so the strip's headline timer
  /// always shows the "ending next" countdown — matches how customers
  /// expect a flash-deal urgency banner to behave.
  Duration _headlineRemaining() {
    if (widget.deals.isEmpty) return Duration.zero;
    final now = DateTime.now();
    final closest = widget.deals
        .map((d) => d.endAt.difference(now))
        .where((d) => !d.isNegative)
        .fold<Duration?>(null, (a, b) => a == null || b < a ? b : a);
    return closest ?? Duration.zero;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deals.isEmpty) return const SizedBox.shrink();
    final remaining = _headlineRemaining();
    final h = _twoDigits(remaining.inHours);
    final m = _twoDigits(remaining.inMinutes.remainder(60));
    final s = _twoDigits(remaining.inSeconds.remainder(60));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE3D2), Color(0xFFFFD2D2)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFE05A2A),
                  size: 22,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Flash Deals',
                  style: TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ends in $h:$m:$s',
                    style: const TextStyle(
                      color: Color(0xFFFFD580),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchPage()),
                  ),
                  child: Row(
                    children: const [
                      Text(
                        'See all',
                        style: TextStyle(
                          color: Color(0xFFE05A2A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFE05A2A),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              itemCount: widget.deals.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
              itemBuilder: (context, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductDetailV2Page(
                      productId: widget.deals[i].productId,
                    ),
                  ),
                ),
                child: _FlashDealCard(product: widget.deals[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlashDealCard extends StatelessWidget {
  const _FlashDealCard({required this.product});
  final FlashDealProduct product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      padding: const EdgeInsets.all(AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: NetworkImageBox(
                    url: resolveImageUrl(product.imageUrl),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                ),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE05A2A),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '-${product.discountPct}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.price,
                style: const TextStyle(
                  color: Color(0xFFE05A2A),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                product.originalPrice,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3D2),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: product.soldPct.clamp(0, 1),
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05A2A),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${(product.soldPct * 100).round()}% claimed',
            style: const TextStyle(
              color: Color(0xFFE05A2A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
