import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

/// Bottom-sheet rating editor. Tap-stars 1..5, optional title, optional
/// body. Server enforces the "only buyers who purchased" rule and
/// returns 403; we surface it inline so the user understands why
/// their post was rejected.
class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({
    super.key,
    required this.productId,
    required this.productName,
  });
  final String productId;
  final String productName;

  /// Returns `true` when a review was successfully posted so the
  /// caller can refresh its summary / list.
  static Future<bool?> show(
    BuildContext context, {
    required String productId,
    required String productName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, _) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: WriteReviewSheet(
            productId: productId,
            productName: productName,
          ),
        ),
      ),
    );
  }

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  int _rating = 5;
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;
  String? _serverError;
  bool _notPurchased = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  static const _ratingLabels = {
    1: 'Poor',
    2: 'Fair',
    3: 'Good',
    4: 'Very good',
    5: 'Excellent',
  };

  Future<void> _submit() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() => _serverError = 'Sign in to leave a review.');
      return;
    }
    setState(() {
      _busy = true;
      _serverError = null;
      _notPurchased = false;
    });
    try {
      await context.read<ReviewsRemoteDataSource>().upsert(
        widget.productId,
        rating: _rating,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        body: _body.text.trim().isEmpty ? null : _body.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReviewWriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Split the "not purchased" case from generic 400s so the
        // explanatory callout reads naturally without the raw message.
        if (e.statusCode == 403) {
          _notPurchased = true;
          _serverError = null;
        } else {
          _serverError = e.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _serverError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              0,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Rate this product',
                    style: Theme.of(context).textTheme.titleLarge?.extraBold,
                  ),
                ),
                IconButton(
                  icon: const AppIcon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.xs,
                AppSizes.lg,
                AppSizes.huge,
              ),
              children: [
                Text(
                  widget.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                _TapStars(
                  value: _rating,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: AppSizes.xs),
                Center(
                  child: Text(
                    _ratingLabels[_rating]!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _rating <= 2
                          ? AppColors.error
                          : _rating == 3
                          ? AppColors.warning
                          : AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.xl),
                if (_notPurchased)
                  Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: ShapeDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const AppIcon(
                          AppIcons.infoOutlineRounded,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            'Only buyers who purchased this product on Shopxy can leave a review. Your order needs to be confirmed first.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_notPurchased) const SizedBox(height: AppSizes.lg),
                TextField(
                  controller: _title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Title (optional)',
                    hintText: 'e.g. Great value for money',
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                TextField(
                  controller: _body,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Your review (optional)',
                    hintText:
                        'What did you like or dislike? How is the quality?',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    _serverError!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                    shape: AppShapes.squircle(AppSizes.radiusMd),
                  ),
                  child: Text(_busy ? 'Posting…' : 'Post review'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TapStars extends StatelessWidget {
  const _TapStars({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final filled = value > i;
        return GestureDetector(
          onTap: () => onChanged(i + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            child: AppIcon(
              filled ? AppIcons.starRounded : AppIcons.starOutlineRounded,
              size: AppSizes.iconHuge,
              color: filled ? AppColors.success : AppColors.subtle,
            ),
          ),
        );
      }),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Container(
        width: 40,
        height: AppSizes.handleHeight,
        decoration: ShapeDecoration(
          color: AppColors.disabled,
          shape: AppShapes.squircle(AppSizes.radiusSm),
        ),
      ),
    );
  }
}
