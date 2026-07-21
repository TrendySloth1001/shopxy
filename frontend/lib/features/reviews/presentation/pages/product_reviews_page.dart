import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy/features/reviews/data/models/product_review.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Merchant-facing read-only listing of reviews for one of their
/// products. Reply / moderation deferred to a later phase.
class ProductReviewsPage extends StatefulWidget {
  const ProductReviewsPage({
    super.key,
    required this.productId,
    required this.productName,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  final int productId;
  final String productName;
  final double? ratingAvg;
  final int ratingCount;

  @override
  State<ProductReviewsPage> createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends State<ProductReviewsPage> {
  final List<ProductReview> _reviews = [];
  bool _loading = true;
  bool _loadingMore = false;
  int? _nextCursor;
  String? _error;
  late final ReviewsRemoteDataSource _ds;

  @override
  void initState() {
    super.initState();
    _ds = context.read<ReviewsRemoteDataSource>();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && _nextCursor == null) return;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final page = await _ds.list(widget.productId, cursor: more ? _nextCursor : null);
      if (!mounted) return;
      setState(() {
        if (!more) _reviews.clear();
        _reviews.addAll(page.data);
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.reviewsTitle(widget.productName)),
      body: _loading && _reviews.isEmpty
          ? const _ReviewsPageSkeleton()
          : _error != null && _reviews.isEmpty
              ? SafeArea(
                  top: true,
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.xl),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: EdgeInsets.only(
                        top: FloatingAppBar.contentTopInset(context),
                        bottom: AppSizes.huge),
                    itemCount: _reviews.length + 2,
                    separatorBuilder: (_, _) => const Divider(height: 0),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _Summary(
                          avg: widget.ratingAvg,
                          count: widget.ratingCount,
                        );
                      }
                      if (i == _reviews.length + 1) {
                        if (_nextCursor != null) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSizes.lg),
                            child: Center(
                              child: _loadingMore
                                  ? const CircularProgressIndicator()
                                  : TextButton(
                                      onPressed: () => _load(more: true),
                                      child: Text(l10n.reviewsLoadMore),
                                    ),
                            ),
                          );
                        }
                        if (_reviews.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSizes.xl),
                            child: Center(
                              child: Text(
                                l10n.reviewsEmpty,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return const SizedBox(height: AppSizes.lg);
                      }
                      return _ReviewTile(review: _reviews[i - 1]);
                    },
                  ),
                ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.avg, required this.count});
  final double? avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      color: AppColors.heroPanel,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.xs,
            ),
            decoration: ShapeDecoration(
              color: AppColors.tileBg(AppColors.brandSoft),
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  avg == null ? '—' : avg!.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.brandStrong,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: AppSizes.xs),
                Icon(AppIcons.starRounded, color: AppColors.brandStrong),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              count == 0
                  ? l10n.reviewsNoneYet
                  : count == 1
                      ? l10n.reviewsCountSingular
                      : l10n.reviewsCountPlural('$count'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final df = DateFormat.yMMMd();
    return Padding(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? AppIcons.starRounded : AppIcons.starOutlineRounded,
                    size: AppSizes.iconSm,
                    color: i < review.rating ? AppColors.brand : AppColors.disabled,
                  );
                }),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  review.userName ?? l10n.reviewsCustomerFallback,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                df.format(review.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
            ],
          ),
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              review.title!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
          if (review.body != null && review.body!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              review.body!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets — shown while the initial page load is in flight.
// ---------------------------------------------------------------------------

/// Full-page skeleton that mirrors the real ListView layout:
/// one _SummarySkeleton followed by [_kSkeletonTileCount] _ReviewTileSkeleton items.
class _ReviewsPageSkeleton extends StatelessWidget {
  const _ReviewsPageSkeleton();

  static const int _kSkeletonTileCount = 3;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      itemCount: 1 + _kSkeletonTileCount,
      separatorBuilder: (context, index) => const Divider(height: 0),
      itemBuilder: (context, i) {
        if (i == 0) return const _SummarySkeleton();
        return const _ReviewTileSkeleton();
      },
    );
  }
}

/// Skeleton for the _Summary hero panel: rating badge box + review-count line.
class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      color: AppColors.heroPanel,
      child: Row(
        children: [
          // Rating badge placeholder — matches the squircle container in _Summary.
          AppShimmerBox(
            width: 64,
            height: 40,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          // Review-count text line.
          const Expanded(
            child: AppShimmerLine(widthFactor: 0.45, height: 14),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a single _ReviewTile:
/// star row, reviewer-name + date, optional title, two-line body.
class _ReviewTileSkeleton extends StatelessWidget {
  const _ReviewTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: star blocks | reviewer name | date
          Row(
            children: [
              // Five star-icon placeholders rendered as a single wide box.
              AppShimmerBox(
                width: AppSizes.iconSm * 5 + AppSizes.xs * 4,
                height: AppSizes.iconSm,
                radius: 4,
              ),
              const SizedBox(width: AppSizes.sm),
              // Reviewer name
              const Expanded(
                child: AppShimmerLine(widthFactor: 0.5, height: 13),
              ),
              const SizedBox(width: AppSizes.sm),
              // Date
              AppShimmerBox(width: 64, height: 11, radius: 4),
            ],
          ),
          // Title line
          const SizedBox(height: AppSizes.sm),
          const AppShimmerLine(widthFactor: 0.6, height: 13),
          // Body — two lines
          const SizedBox(height: AppSizes.xs),
          const AppShimmerLine(widthFactor: 1.0, height: 13),
          const SizedBox(height: AppSizes.xs),
          const AppShimmerLine(widthFactor: 0.75, height: 13),
        ],
      ),
    );
  }
}
