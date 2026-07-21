import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/coupons/data/datasources/coupons_remote_data_source.dart';
import 'package:shopxy_customer/features/coupons/domain/entities/coupon.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// "My coupons" — read-only list of redeemable promo codes. Customers
/// copy a code here and paste it into the checkout sheet. Exhausted
/// coupons stay visible with a muted "Used" badge so the user has a
/// memory of what they've already used.
class MyCouponsPage extends StatefulWidget {
  const MyCouponsPage({super.key});

  @override
  State<MyCouponsPage> createState() => _MyCouponsPageState();
}

class _MyCouponsPageState extends State<MyCouponsPage> {
  late Future<List<Coupon>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Coupon>> _load() =>
      context.read<CouponsRemoteDataSource>().listAvailable();

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'My coupons'),
      body: FutureBuilder<List<Coupon>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return ListView.separated(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (_, _) => const _CouponCardSkeleton(),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xxl),
                child: Text(friendlyError(snap.error ?? '')),
              ),
            );
          }
          final coupons = snap.data ?? const <Coupon>[];
          if (coupons.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: coupons.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (_, i) => _CouponCard(coupon: coupons[i]),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton card that mirrors the layout of [_CouponCard].
class _CouponCardSkeleton extends StatelessWidget {
  const _CouponCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row — wide line + small pill placeholder on the right
          Row(
            children: [
              const Expanded(
                child: AppShimmerLine(widthFactor: 0.55, height: 14),
              ),
              const SizedBox(width: AppSizes.sm),
              AppShimmerBox(
                width: 72,
                height: 20,
                radius: AppSizes.radiusFull,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          // Headline / benefit line
          const AppShimmerLine(widthFactor: 0.40, height: 13),
          const SizedBox(height: AppSizes.xs),
          // Optional min-order label
          const AppShimmerLine(widthFactor: 0.30, height: 11),
          const SizedBox(height: AppSizes.sm),
          // Optional description — two shorter lines
          const AppShimmerLine(widthFactor: 0.85, height: 11),
          const SizedBox(height: AppSizes.xs),
          const AppShimmerLine(widthFactor: 0.65, height: 11),
          const SizedBox(height: AppSizes.sm),
          // Bottom row: code badge + expiry date
          Row(
            children: [
              AppShimmerBox(
                width: 90,
                height: 28,
                radius: AppSizes.radiusSm,
              ),
              const Spacer(),
              const AppShimmerLine(widthFactor: 0.22, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});
  final Coupon coupon;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: coupon.code));
    if (!context.mounted) return;
    showAppSnackbar(
      context,
      message: 'Copied ${coupon.code}',
      tone: AppSnackbarTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exhausted = coupon.exhausted;
    return Opacity(
      opacity: exhausted ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    coupon.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (coupon.firstOrderOnly)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSizes.sm),
                    child: _CouponPill(
                      label: 'First order only',
                      bg: AppColors.accentAmberSoft,
                      fg: AppColors.accentAmber,
                    ),
                  ),
                if (coupon.isPublic)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSizes.sm),
                    child: _CouponPill(
                      label: 'Auto-applies',
                      bg: AppColors.brandSoft,
                      fg: AppColors.brandStrong,
                    ),
                  ),
                if (exhausted)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSizes.sm),
                    child: _CouponPill(
                      label: 'Used',
                      bg: AppColors.surfaceTint,
                      fg: AppColors.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              coupon.headline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (coupon.minOrderLabel.isNotEmpty) ...[
              const SizedBox(height: AppSizes.xs),
              Text(
                coupon.minOrderLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
            if (coupon.description != null && coupon.description!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Text(
                coupon.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.brandSoft,
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  child: Text(
                    coupon.code,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.brandStrong,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                TextButton.icon(
                  onPressed: exhausted ? null : () => _copy(context),
                  icon: const Icon(AppIcons.copyRounded, size: AppSizes.iconSm),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Spacer(),
                Text(
                  'Expires ${DateFormat('d MMM').format(coupon.validUntil.toLocal())}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponPill extends StatelessWidget {
  const _CouponPill({
    required this.label,
    required this.bg,
    required this.fg,
  });
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.localOfferOutlined,
                size: AppSizes.iconHuge, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            Text(
              'No coupons yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Promo codes you earn will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
