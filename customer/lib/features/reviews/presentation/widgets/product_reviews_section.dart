import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy_customer/features/reviews/domain/entities/review.dart';
import 'package:shopxy_customer/features/reviews/presentation/pages/all_reviews_page.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/write_review_sheet.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/review_tile.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/star_row.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

/// Ratings & reviews block on the product detail page. Loads its own
/// summary in initState so the surrounding PDP build never blocks on
/// review counts — when the summary is loading we render a slim
/// skeleton; on error the block hides itself (the PDP works fine
/// without it).
class ProductReviewsSection extends StatefulWidget {
  const ProductReviewsSection({
    super.key,
    required this.productId,
    required this.productName,
  });
  final String productId;
  final String productName;

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  late final ReviewsRemoteDataSource _ds;
  ReviewSummary? _summary;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ds = context.read<ReviewsRemoteDataSource>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _ds.getSummary(widget.productId);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _openAllReviews() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllReviewsPage(
          productId: widget.productId,
          productName: widget.productName,
        ),
      ),
    );
    // Refresh on return — the user might have written a review while
    // they were on the all-reviews page.
    if (mounted) _load();
  }

  Future<void> _openWriteSheet() async {
    final signedIn = await requireAuth(
      context,
      reason: 'Sign in to leave a rating or review for this product.',
    );
    if (!signedIn || !mounted) return;
    final result = await WriteReviewSheet.show(
      context,
      productId: widget.productId,
      productName: widget.productName,
    );
    if (result == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return const SizedBox.shrink();
    if (_loading) return const _SectionSkeleton();
    final s = _summary!;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: AppSizes.md),
      color: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Ratings & Reviews',
                    style: theme.textTheme.titleMedium?.extraBold,
                  ),
                ),
                TextButton(
                  onPressed: _openWriteSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandStrong,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppIcon(
                        AppIcons.editOutlined,
                        size: AppSizes.iconSm,
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Text(
                        'Rate product',
                        style: theme.textTheme.labelMedium?.extraBold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s.ratingCount == 0)
            const _EmptyState()
          else ...[
            _SummaryRow(summary: s),
            const Divider(height: 1, color: AppColors.hairline),
            for (int i = 0; i < s.recent.length; i++) ...[
              ReviewTile(review: s.recent[i], dense: true),
              if (i < s.recent.length - 1)
                const Divider(
                  height: 1,
                  color: AppColors.hairline,
                  indent: AppSizes.lg,
                  endIndent: AppSizes.lg,
                ),
            ],
            const Divider(height: 1, color: AppColors.hairline),
            InkWell(
              onTap: _openAllReviews,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.md,
                ),
                child: Row(
                  children: [
                    Text(
                      'See all ${s.ratingCount} ${s.ratingCount == 1 ? "review" : "reviews"}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.brandStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: AppSizes.xs),
                    const AppIcon(
                      AppIcons.chevronRightRounded,
                      color: AppColors.brandStrong,
                      size: AppSizes.iconMd,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Top half of the section: big number + star row + count on the left,
/// 5-bar histogram on the right. Reads at a glance the way Flipkart
/// and Amazon do it.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});
  final ReviewSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avg = summary.ratingAvg ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: Text(
                      '/ 5',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              StarRow(rating: avg, size: AppSizes.lg),
              const SizedBox(height: AppSizes.xs),
              Text(
                '${summary.ratingCount} ${summary.ratingCount == 1 ? "rating" : "ratings"}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.xl),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int star = 5; star >= 1; star--)
                  _HistogramRow(
                    label: star,
                    value: summary.histogram[star] ?? 0,
                    total: summary.ratingCount,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistogramRow extends StatelessWidget {
  const _HistogramRow({
    required this.label,
    required this.value,
    required this.total,
  });
  final int label;
  final int value;
  final int total;

  Color get _barColor {
    if (label <= 2) return AppColors.error;
    if (label == 3) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          SizedBox(
            width: AppSizes.lg,
            child: Text(
              '$label',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall?.bold,
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          const AppIcon(
            AppIcons.starRounded,
            size: AppSizes.iconSm,
            color: AppColors.subtle,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
              child: Stack(
                children: [
                  Container(height: AppSizes.sm, color: AppColors.heroPanel),
                  // FractionallySizedBox in a Stack would clip to parent
                  // width; AnimatedContainer with LayoutBuilder works
                  // but for a static read of fraction a plain width
                  // multiplier on the inner bar is fine and cheap.
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(height: AppSizes.sm, color: _barColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          SizedBox(
            width: AppSizes.xxl,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.lg,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: AppColors.heroPanel,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Row(
          children: [
            const AppIcon(
              AppIcons.reviewsOutlined,
              color: AppColors.muted,
              size: AppSizes.iconXl,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No reviews yet',
                    style: Theme.of(context).textTheme.titleSmall?.extraBold,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'Be the first to rate this product after your purchase is delivered.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
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

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();
  @override
  Widget build(BuildContext context) {
    Widget bar({
      double w = double.infinity,
      double h = AppSizes.md,
      double r = AppSizes.radiusSm,
    }) => Container(
      width: w,
      height: h,
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(r),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.md),
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(w: AppSizes.massive, h: AppSizes.xxxl, r: AppSizes.radiusSm),
              const SizedBox(height: AppSizes.sm),
              bar(w: 80),
              const SizedBox(height: AppSizes.sm),
              bar(w: AppSizes.huge),
            ],
          ),
          const SizedBox(width: AppSizes.xl),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < 5; i++) ...[
                  bar(h: AppSizes.sm),
                  if (i < 4) const SizedBox(height: AppSizes.xs),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
