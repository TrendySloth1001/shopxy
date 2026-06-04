import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/listing_filters.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Modal bottom sheet for editing [ListingFilters] against a fixed set
/// of [ListingFacets]. Local mutation only — the caller commits the
/// edited filters by reading the return value of [showModalBottomSheet].
///
/// Returns:
///   * the edited [ListingFilters] when the user taps "Apply"
///   * null when the sheet is dismissed without applying
Future<ListingFilters?> showFilterSheet({
  required BuildContext context,
  required ListingFilters initial,
  required ListingFacets facets,
}) {
  return showModalBottomSheet<ListingFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    useSafeArea: true,
    shape: AppShapes.squircleTop(AppSizes.radiusXl),
    builder: (_) => _FilterSheet(initial: initial, facets: facets),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.facets});
  final ListingFilters initial;
  final ListingFacets facets;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListingFilters _draft;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    final lo = widget.facets.priceMin;
    final hi = widget.facets.priceMax > lo ? widget.facets.priceMax : lo + 1;
    _priceRange = RangeValues(
      (_draft.priceMin ?? lo).clamp(lo, hi).toDouble(),
      (_draft.priceMax ?? hi).clamp(lo, hi).toDouble(),
    );
  }

  void _onPriceChanged(RangeValues v) {
    setState(() => _priceRange = v);
  }

  void _commitPrice() {
    final lo = widget.facets.priceMin;
    final hi = widget.facets.priceMax > lo ? widget.facets.priceMax : lo + 1;
    setState(() {
      _draft = _draft.copyWith(
        priceMin: _priceRange.start <= lo ? null : _priceRange.start,
        priceMax: _priceRange.end >= hi ? null : _priceRange.end,
      );
    });
  }

  void _setRatingMin(double? v) {
    setState(() => _draft = _draft.copyWith(ratingMin: v));
  }

  void _toggleInStock(bool v) {
    setState(() => _draft = _draft.copyWith(inStock: v));
  }

  void _toggleBrand(int shopId) {
    final next = [..._draft.shopIds];
    next.remove(shopId);
    if (!_draft.shopIds.contains(shopId)) next.add(shopId);
    setState(() => _draft = _draft.copyWith(shopIds: next));
  }

  void _reset() {
    setState(() {
      _draft = ListingFilters.none;
      final lo = widget.facets.priceMin;
      final hi = widget.facets.priceMax > lo ? widget.facets.priceMax : lo + 1;
      _priceRange = RangeValues(lo.toDouble(), hi.toDouble());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facets = widget.facets;
    final hasPrice = facets.priceMax > facets.priceMin;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filters',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (!_draft.isEmpty)
                  TextButton(
                    onPressed: _reset,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                    ),
                    child: const Text('Reset'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.lg,
              ),
              children: [
                if (hasPrice) ...[
                  _SectionTitle('Price'),
                  RangeSlider(
                    values: _priceRange,
                    min: facets.priceMin.toDouble(),
                    max: facets.priceMax.toDouble(),
                    divisions: 20,
                    labels: RangeLabels(
                      '₹${_priceRange.start.round()}',
                      '₹${_priceRange.end.round()}',
                    ),
                    onChanged: _onPriceChanged,
                    onChangeEnd: (_) => _commitPrice(),
                    activeColor: AppColors.brand,
                    inactiveColor: AppColors.hairline,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${_priceRange.start.round()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          '₹${_priceRange.end.round()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                ],

                _SectionTitle('Customer rating'),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    _RatingChip(
                      label: '4★ & up',
                      count: facets.gte4Count,
                      selected: _draft.ratingMin == 4,
                      onTap: () => _setRatingMin(_draft.ratingMin == 4 ? null : 4),
                    ),
                    _RatingChip(
                      label: '3★ & up',
                      count: facets.gte3Count,
                      selected: _draft.ratingMin == 3,
                      onTap: () => _setRatingMin(_draft.ratingMin == 3 ? null : 3),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),

                _SectionTitle('Availability'),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('In stock only'),
                  subtitle: Text(
                    '${facets.inStockCount} products available',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  value: _draft.inStock,
                  activeThumbColor: AppColors.brand,
                  onChanged: _toggleInStock,
                ),
                const SizedBox(height: AppSizes.md),

                if (facets.brands.isNotEmpty) ...[
                  _SectionTitle('Brand'),
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.sm,
                    children: [
                      for (final b in facets.brands)
                        _BrandChip(
                          brand: b,
                          selected: _draft.shopIds.contains(b.shopId),
                          onTap: () => _toggleBrand(b.shopId),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                      side: const BorderSide(color: AppColors.hairline),
                      foregroundColor: AppColors.black,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      _commitPrice();
                      Navigator.pop(context, _draft);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: Text(
                      _draft.isEmpty ? 'Show results' : 'Apply filters',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      selected: selected,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: AppSizes.sm),
            Text(
              '($count)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? AppColors.white.withValues(alpha: 0.7)
                        : AppColors.muted,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandChip extends StatelessWidget {
  const _BrandChip({
    required this.brand,
    required this.selected,
    required this.onTap,
  });
  final BrandFacet brand;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChipShell(
      selected: selected,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(brand.name),
          const SizedBox(width: AppSizes.sm),
          Text(
            '(${brand.count})',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected
                      ? AppColors.white.withValues(alpha: 0.7)
                      : AppColors.muted,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChipShell extends StatelessWidget {
  const _ChipShell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.black : AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(
          color: selected ? AppColors.black : AppColors.hairline,
        ),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? AppColors.white : AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
            child: child,
          ),
        ),
      ),
    );
  }
}
