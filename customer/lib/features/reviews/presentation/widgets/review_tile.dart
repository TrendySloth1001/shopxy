import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy_customer/features/reviews/domain/review.dart';
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
            ],
          ),
          if (review.body != null && review.body!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.body!,
              maxLines: dense ? 4 : null,
              overflow: dense ? TextOverflow.ellipsis : TextOverflow.visible,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.black,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppColors.brandStrong,
                    fontSize: 11,
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
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              // The backend gates writes by purchase, so every review
              // we show *was* posted by a buyer — surface that fact
              // explicitly the way Flipkart/Amazon do.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: ShapeDecoration(
                  color: AppColors.successSoft,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 11,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Verified buyer',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                _df.format(review.createdAt.toLocal()),
                style: const TextStyle(
                  color: AppColors.subtle,
                  fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rating',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.star_rounded, color: Colors.white, size: 11),
        ],
      ),
    );
  }
}
