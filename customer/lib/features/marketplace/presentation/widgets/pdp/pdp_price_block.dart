import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';

class PdpPriceBlock extends StatelessWidget {
  const PdpPriceBlock({
    super.key,
    required this.product,
    this.variantOverride,
  });
  final MarketplaceProduct product;

  final MarketplaceVariant? variantOverride;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final v = variantOverride;
    final price = v?.sellingPrice ?? p.sellingPrice;
    final mrp = v?.mrp ?? p.mrp;
    final isDiscounted = mrp > 0 && mrp > price;
    final pct = isDiscounted ? (((mrp - price) / mrp) * 100).round() : 0;
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
                AppFormat.rupees(price),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
              ),
              const SizedBox(width: AppSizes.sm),
              if (isDiscounted)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.xs),
                  child: Text(
                    'M.R.P. ${AppFormat.rupees(mrp)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                        ),
                  ),
                ),
              const SizedBox(width: AppSizes.sm),
              if (isDiscounted)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm, vertical: AppSizes.xs),
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Text(
                    '$pct% off',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.xs),
            child: Text(
              isDiscounted
                  ? 'Inclusive of all taxes'
                  : 'M.R.P. ${AppFormat.rupees(mrp)} · inclusive of all taxes',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ..._complianceRows(context, p),
        ],
      ),
    );
  }

  List<Widget> _complianceRows(BuildContext context, MarketplaceProduct p) {
    final rows = <List<String>>[];
    final coo = p.countryOfOrigin;
    if (coo != null && coo.isNotEmpty) rows.add(['Country of origin', coo]);
    if (p.unit.isNotEmpty) rows.add(['Net quantity', p.unit]);
    final brand = p.brand;
    if (brand != null && brand.isNotEmpty) rows.add(['Marketed by', brand]);
    if (rows.isEmpty) return const [];

    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        );
    final valueStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.black,
          fontWeight: FontWeight.w700,
        );
    return [
      Padding(
        padding: const EdgeInsets.only(top: AppSizes.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(r[0], style: labelStyle),
                    ),
                    Expanded(child: Text(r[1], style: valueStyle)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }
}
