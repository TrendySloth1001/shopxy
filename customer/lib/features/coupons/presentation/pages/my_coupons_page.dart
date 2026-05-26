import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/coupons/data/datasources/coupons_remote_data_source.dart';
import 'package:shopxy_customer/features/coupons/domain/coupon.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

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
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString().replaceFirst('Exception: ', '')),
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
                if (exhausted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.surfaceTint,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                    ),
                    child: const Text(
                      'Used',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              coupon.headline,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            if (coupon.minOrderLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                coupon.minOrderLabel,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
            if (coupon.description != null && coupon.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
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
                    vertical: 4,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.brandSoft,
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  child: Text(
                    coupon.code,
                    style: const TextStyle(
                      color: AppColors.brandStrong,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                TextButton.icon(
                  onPressed: exhausted ? null : () => _copy(context),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const Spacer(),
                Text(
                  'Expires ${DateFormat('d MMM').format(coupon.validUntil.toLocal())}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
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
            const Icon(Icons.local_offer_outlined,
                size: 48, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            Text(
              'No coupons yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'Promo codes you earn will appear here.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
