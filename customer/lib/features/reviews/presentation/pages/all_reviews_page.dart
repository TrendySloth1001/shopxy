import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy_customer/features/reviews/domain/review.dart';
import 'package:shopxy_customer/features/reviews/presentation/pages/write_review_sheet.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/review_tile.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/star_row.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

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
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Rate product'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _initialLoad && _reviews.isEmpty
            ? const Center(child: CircularProgressIndicator())
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
        children: const [
          SizedBox(height: 80),
          Center(
            child: Padding(
              padding: EdgeInsets.all(AppSizes.xl),
              child: Column(
                children: [
                  StarRow(rating: 0, size: 28),
                  SizedBox(height: AppSizes.sm),
                  Text(
                    'No reviews match this filter.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
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
      padding: const EdgeInsets.only(bottom: 96),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 6,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.muted),
            const SizedBox(height: AppSizes.sm),
            const Text(
              "Couldn't load reviews",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
    );
  }
}
