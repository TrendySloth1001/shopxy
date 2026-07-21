import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

/// Phase G — "Frequently bought together" rail. Sits between the offers
/// strip and the tab bar in the PDP. Self-loads its own cohort on
/// init; renders nothing while loading or on error so it can never
/// block the PDP. Empty arrays from the server also collapse to
/// nothing (no rail when there's no cohort).
class PdpFbtRail extends StatefulWidget {
  const PdpFbtRail({super.key, required this.productId});
  final int productId;

  @override
  State<PdpFbtRail> createState() => _PdpFbtRailState();
}

class _PdpFbtRailState extends State<PdpFbtRail> {
  List<MarketplaceFbtCard>? _items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final ds = context.read<MarketplaceRemoteDataSource>();
      final items = await ds.frequentlyBoughtTogether(widget.productId);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {
      // Rail is purely additive — swallow errors and hide it.
      if (!mounted) return;
      setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSizes.md, 0, AppSizes.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              'Frequently bought together',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            // 140px square image + ~88px body (name 2 lines, price row,
            // optional rating row, 16px padding). A couple of devices
            // were clipping by 4px at the default scale — 232 buys the
            // headroom and absorbs a +10% text-scale setting too.
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (_, i) => _Card(card: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});
  final MarketplaceFbtCard card;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(productId: card.id),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: card.imageUrl == null
                    ? Container(color: AppColors.heroPanel)
                    : NetworkImageBox(
                        url: resolveImageUrl(card.imageUrl!),
                        fit: BoxFit.cover,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSizes.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      children: [
                        Text(
                          AppFormat.rupees(card.sellingPrice),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.black,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (card.isDiscounted) ...[
                          const SizedBox(width: AppSizes.xs),
                          Text(
                            AppFormat.rupees(card.mrp),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        ],
                      ],
                    ),
                    if (card.ratingAvg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSizes.xs),
                        child: Row(
                          children: [
                            const AppIcon(
                              AppIcons.starRounded,
                              color: Color(0xFFE05A2A),
                              size: 12,
                            ),
                            const SizedBox(width: AppSizes.xs),
                            Text(
                              '${card.ratingAvg!.toStringAsFixed(1)} (${card.ratingCount})',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
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
