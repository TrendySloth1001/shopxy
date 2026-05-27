import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Price block + active flash-sale countdown. When [MarketplaceProduct.flashSale]
/// is non-null and `endAt > now`, the price uses the flash price and a
/// countdown chip sits beneath it. The countdown ticks every second
/// against the wall clock; when it elapses we drop back to the regular
/// [MarketplaceProduct.sellingPrice] without rebuilding the rest of the
/// PDP.
class PdpPriceBlock extends StatefulWidget {
  const PdpPriceBlock({
    super.key,
    required this.product,
    this.variantOverride,
  });
  final MarketplaceProduct product;
  /// Phase E — when set, the price block reads pricing/stock from this
  /// variant instead of the product-level fields. Null while the
  /// customer hasn't picked anything; the picker seeds with the
  /// default variant on load so this is effectively non-null in
  /// practice. Flash-sale state still comes from product.flashSale.
  final MarketplaceVariant? variantOverride;

  @override
  State<PdpPriceBlock> createState() => _PdpPriceBlockState();
}

class _PdpPriceBlockState extends State<PdpPriceBlock> {
  Timer? _tick;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    final sale = widget.product.flashSale;
    if (sale != null) {
      _remaining = sale.endAt.difference(DateTime.now());
      if (!_remaining.isNegative) {
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          final r = sale.endAt.difference(DateTime.now());
          if (!mounted) return;
          if (r.isNegative) {
            _tick?.cancel();
            setState(() => _remaining = Duration.zero);
          } else {
            setState(() => _remaining = r);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = two(d.inHours);
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final v = widget.variantOverride;
    final saleActive = p.flashSale != null && !_remaining.isNegative && _remaining > Duration.zero;
    // Variant pricing wins when one is selected; flash sale still
    // overrides since marketplace policy hangs flash sales off the
    // product, not the variant (v1).
    final basePrice = v?.sellingPrice ?? p.sellingPrice;
    final baseMrp = v?.mrp ?? p.mrp;
    final price = saleActive ? p.flashSale!.price : basePrice;
    final isDiscounted = baseMrp > 0 && baseMrp > price;
    final pct = isDiscounted ? (((baseMrp - price) / baseMrp) * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${price.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              if (isDiscounted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'M.R.P. ₹${baseMrp.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              const SizedBox(width: AppSizes.sm),
              if (isDiscounted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$pct% off',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (p.taxPercent > 0)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Inclusive of all taxes',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (saleActive) ...[
            const SizedBox(height: AppSizes.sm),
            _FlashChip(sale: p.flashSale!, label: _fmt(_remaining)),
          ],
        ],
      ),
    );
  }
}

class _FlashChip extends StatelessWidget {
  const _FlashChip({required this.sale, required this.label});
  final ActiveFlashSale sale;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: 6),
      decoration: ShapeDecoration(
        color: const Color(0xFFFFE3D2),
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded,
              color: Color(0xFFE05A2A), size: 16),
          const SizedBox(width: 4),
          Text(
            'Flash deal · ends in $label',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          if (sale.stockLimit > 0) ...[
            const SizedBox(width: AppSizes.sm),
            Text(
              '${sale.remaining} left',
              style: const TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
