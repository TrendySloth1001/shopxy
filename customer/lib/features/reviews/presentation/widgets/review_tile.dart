import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy_customer/features/reviews/domain/entities/review.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// One review row — used both inline in the PDP recent-reviews block
/// and on the full all-reviews page. Designed to read like Flipkart:
/// green rating pill, then title, then body, then author + date and
/// a "Verified buyer" chip on the right.
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.dense = false});
  final Review review;
  /// Compact mode trims the body to 4 lines + drops the divider — used
  /// in the PDP card stack where there's a hard height budget.
  final bool dense;

  static final DateFormat _df = DateFormat.yMMMMd();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = review.authorName.trim().isEmpty
        ? '?'
        : review.authorName.trim()[0].toUpperCase();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: dense ? AppSizes.sm : AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RatingChip(rating: review.rating),
              const SizedBox(width: AppSizes.sm),
              if (review.title != null && review.title!.isNotEmpty)
                Expanded(
                  child: Text(
                    review.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (review.body != null && review.body!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              review.body!,
              maxLines: dense ? 4 : null,
              overflow: dense ? TextOverflow.ellipsis : TextOverflow.visible,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Container(
                width: AppSizes.xxl,
                height: AppSizes.xxl,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Flexible(
                child: Text(
                  review.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              // The backend gates writes by purchase, so every review
              // we show *was* posted by a buyer — surface that fact
              // explicitly the way Flipkart/Amazon do.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xs,
                  vertical: AppSizes.xs,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.successSoft,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: AppSizes.iconSm,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      'Verified buyer',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _df.format(review.createdAt.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.subtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "4 ★" green pill — same component Flipkart uses next to titles.
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});
  final int rating;

  Color get _color {
    // 1-2 = red, 3 = amber, 4-5 = green — matches the convention most
    // marketplaces use so first-time customers don't need to learn it.
    if (rating <= 2) return AppColors.error;
    if (rating == 3) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: _color,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rating',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(width: AppSizes.xs),
          const Icon(
            Icons.star_rounded,
            color: AppColors.white,
            size: AppSizes.iconSm,
          ),
        ],
      ),
    );
  }
}
