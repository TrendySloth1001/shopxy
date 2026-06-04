import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy_customer/features/reviews/domain/entities/review.dart';
import 'package:shopxy_customer/features/reviews/presentation/widgets/star_row.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';

/// "My reviews" — every review the caller has written, newest first.
/// Tap a row → PDP. Cursor-paginated; loads next page when the user
/// scrolls within ~400px of the bottom. Refreshable via pull-down.
class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage> {
  late final ReviewsRemoteDataSource _ds;
  final _scroll = ScrollController();
  final List<MyReview> _rows = [];
  int? _cursor;
  bool _loading = false;
  bool _initialLoad = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ds = context.read<ReviewsRemoteDataSource>();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_maybeLoadMore);
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_loading || _cursor == null) return;
    if (_scroll.position.pixels >
        _scroll.position.maxScrollExtent - 400) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _ds.listMine(cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _rows.clear();
        _rows.addAll(page.data);
        _cursor = page.nextCursor;
        _initialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _initialLoad = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'My reviews'),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () => _load(reset: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoad && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _rows.isEmpty) {
      return _ErrorBlock(message: _error!, onRetry: () => _load(reset: true));
    }
    if (_rows.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      itemCount: _rows.length + (_cursor != null ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, i) {
        if (i >= _rows.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _Row(row: _rows[i]);
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final MyReview row;

  static final _date = DateFormat('d MMM y');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppShapes.squircle(
      AppSizes.radiusMd,
      side: const BorderSide(color: AppColors.hairline),
    );
    return Material(
      color: AppColors.white,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(productId: row.productId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ProductThumb(url: row.productImage),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.productName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSizes.xs),
                        StarRow(
                          rating: row.review.rating.toDouble(),
                          size: AppSizes.lg,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _date.format(row.review.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              if ((row.review.title ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  row.review.title!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if ((row.review.body ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSizes.xs),
                Text(
                  row.review.body!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  const _ProductThumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final shape = AppShapes.squircle(AppSizes.radiusSm);
    if (url == null || url!.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: ShapeDecoration(
          color: AppColors.heroPanel,
          shape: shape,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: AppColors.subtle),
      );
    }
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: Image.network(
        resolveImageUrl(url!),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 56,
          height: 56,
          color: AppColors.heroPanel,
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, color: AppColors.subtle),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSizes.xl),
      children: [
        const SizedBox(height: AppSizes.huge),
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: AppColors.warningSoft,
            shape: AppShapes.squircle(AppSizes.radiusLg),
          ),
          child: const Icon(
            Icons.rate_review_outlined,
            size: AppSizes.iconXl,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(
          'No reviews yet',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Once you receive an order, you can rate and review the '
          'products you bought.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
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
            const Icon(Icons.error_outline_rounded,
                size: AppSizes.iconHuge, color: AppColors.error),
            const SizedBox(height: AppSizes.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            AppButton.secondary(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () => onRetry(),
            ),
          ],
        ),
      ),
    );
  }
}
