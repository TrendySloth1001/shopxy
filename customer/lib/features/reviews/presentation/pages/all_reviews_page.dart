import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy_customer/features/reviews/domain/entities/review.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/write_review_sheet.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/review_tile.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/star_row.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// Paginated all-reviews page. Loads page 1 on mount; appends pages as
/// the user scrolls within ~400px of the bottom. Filter chips switch
/// between "All" and a single-star bucket — the bucket request still
/// pages from the same /reviews endpoint and filters client-side
/// (cheap; review counts per product are bounded).
class AllReviewsPage extends StatefulWidget {
  const AllReviewsPage({
    super.key,
    required this.productId,
    required this.productName,
  });
  final int productId;
  final String productName;

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  late final ReviewsRemoteDataSource _ds;
  final _scroll = ScrollController();
  final List<Review> _reviews = [];
  int? _cursor;
  bool _loading = false;
  bool _initialLoad = true;
  String? _error;
  int _filterStar = 0; // 0 = all

  @override
  void initState() {
    super.initState();
    _ds = context.read<ReviewsRemoteDataSource>();
    _scroll.addListener(_maybeLoadMore);
    _loadNext();
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_loading || _cursor == null) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels < 400) _loadNext();
  }

  Future<void> _loadNext() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final page = await _ds.list(
        widget.productId,
        cursor: _cursor,
      );
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.data);
        _cursor = page.nextCursor;
        _loading = false;
        _initialLoad = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _initialLoad = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _reviews.clear();
      _cursor = null;
      _initialLoad = true;
    });
    await _loadNext();
  }

  Future<void> _openWriteSheet() async {
    final ok = await WriteReviewSheet.show(
      context,
      productId: widget.productId,
      productName: widget.productName,
    );
    if (ok == true) await _refresh();
  }

  Iterable<Review> get _visible {
    if (_filterStar == 0) return _reviews;
    return _reviews.where((r) => r.rating == _filterStar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Ratings & reviews'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.sm,
              ),
              children: [
                for (int i = 0; i <= 5; i++) ...[
                  _FilterChip(
                    label: i == 0 ? 'All' : '$i ★',
                    selected: _filterStar == i,
                    onTap: () => setState(() => _filterStar = i),
                  ),
                  const SizedBox(width: AppSizes.xs),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openWriteSheet,
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.white,
        icon: const Icon(AppIcons.editOutlined),
        label: const Text('Rate product'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _initialLoad && _reviews.isEmpty
            ? const _AllReviewsSkeleton()
            : _error != null && _reviews.isEmpty
                ? _ErrorView(message: _error!, onRetry: _refresh)
                : _buildList(),
      ),
    );
  }

  Widget _buildList() {
    final list = _visible.toList(growable: false);
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Column(
                children: [
                  const StarRow(rating: 0, size: AppSizes.iconXl),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'No reviews match this filter.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: AppSizes.fabClearance),
      itemCount: list.length + ((_cursor != null || _loading) ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: AppColors.hairline,
        indent: AppSizes.lg,
        endIndent: AppSizes.lg,
      ),
      itemBuilder: (_, i) {
        if (i >= list.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSizes.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return ReviewTile(review: list[i]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets
// ---------------------------------------------------------------------------

/// Single shimmer tile that mirrors the layout of [ReviewTile].
class _ReviewTileSkeleton extends StatelessWidget {
  const _ReviewTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating chip + verified badge row
          Row(
            children: [
              AppShimmerBox(
                width: 52,
                height: 24,
                radius: AppSizes.radiusFull,
              ),
              const SizedBox(width: AppSizes.sm),
              AppShimmerBox(
                width: 72,
                height: 20,
                radius: AppSizes.radiusSm,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          // Review title
          AppShimmerLine(widthFactor: 0.70, height: 14),
          const SizedBox(height: AppSizes.xs),
          // Body lines
          AppShimmerLine(widthFactor: 1.0, height: 12),
          const SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.92, height: 12),
          const SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.65, height: 12),
          const SizedBox(height: AppSizes.sm),
          // Author row: avatar + name
          Row(
            children: [
              AppShimmerBox(
                width: 32,
                height: 32,
                radius: 16, // circular
              ),
              const SizedBox(width: AppSizes.sm),
              AppShimmerLine(widthFactor: 0.35, height: 12),
              const Spacer(),
              // Date
              AppShimmerLine(widthFactor: 0.18, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-page skeleton: renders 4 shimmer review tiles separated by hairline
/// dividers, matching [_buildList]'s separator style.
class _AllReviewsSkeleton extends StatelessWidget {
  const _AllReviewsSkeleton();

  static const int _tileCount = 4;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.fabClearance),
      itemCount: _tileCount,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        color: AppColors.hairline,
        indent: AppSizes.lg,
        endIndent: AppSizes.lg,
      ),
      itemBuilder: (_, _) => const _ReviewTileSkeleton(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.brand : AppColors.heroPanel,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.white : AppColors.black,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.cloudOffOutlined,
                size: AppSizes.iconHuge, color: AppColors.muted),
            const SizedBox(height: AppSizes.sm),
            Text(
              "Couldn't load reviews",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.md),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(AppIcons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
