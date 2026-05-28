import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy/features/reviews/data/models/product_review.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

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
      setState(() => _error = e.toString());
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
    return Scaffold(
      appBar: AppBar(title: Text('Reviews · ${widget.productName}')),
      body: _loading && _reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _reviews.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: AppSizes.huge),
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
                                      child: const Text('Load more'),
                                    ),
                            ),
                          );
                        }
                        if (_reviews.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSizes.xl),
                            child: Center(
                              child: Text(
                                'No reviews yet — they\'ll show up here once buyers leave one.',
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
              color: AppColors.brandSoft,
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
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, color: AppColors.brandStrong),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              count == 0 ? 'No reviews yet' : '$count review${count == 1 ? '' : 's'}',
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
                    i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: i < review.rating ? AppColors.brand : AppColors.disabled,
                  );
                }),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  review.userName ?? 'Customer',
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
            const SizedBox(height: 4),
            Text(
              review.title!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
          if (review.body != null && review.body!.isNotEmpty) ...[
            const SizedBox(height: 4),
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
