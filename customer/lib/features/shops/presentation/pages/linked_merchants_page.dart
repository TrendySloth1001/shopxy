import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_merchant.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/linked_merchants_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

/// Customer-side directory of merchants the user has an active Party
/// or Vendor link with. Each card opens the marketplace `ShopProfilePage`
/// for that shop, restricted to that merchant's catalog.
class LinkedMerchantsPage extends StatefulWidget {
  const LinkedMerchantsPage({super.key});

  @override
  State<LinkedMerchantsPage> createState() => _LinkedMerchantsPageState();
}

class _LinkedMerchantsPageState extends State<LinkedMerchantsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LinkedMerchantsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<LinkedMerchantsProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(
        title: 'Linked merchants',
        subtitle: 'Browse the shops that invited you',
      ),
      body: RefreshIndicator(
        onRefresh: p.load,
        color: AppColors.brand,
        child: p.isLoading && p.items.isEmpty
            ? const _MerchantListSkeleton()
            : p.error != null && p.items.isEmpty
            ? _ErrorState(message: p.error!, onRetry: p.load)
            : p.items.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.md,
                ),
                itemCount: p.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
                itemBuilder: (_, i) => _MerchantCard(merchant: p.items[i]),
              ),
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.merchant});
  final LinkedMerchant merchant;

  @override
  Widget build(BuildContext context) {
    final shape = AppShapes.squircle(
      AppSizes.radiusLg,
      side: const BorderSide(color: AppColors.hairline),
    );
    return Material(
      color: AppColors.white,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShopProfilePage(slug: merchant.slug),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (merchant.bannerUrl != null)
              AspectRatio(
                aspectRatio: 16 / 6,
                child: NetworkImageBox(
                  url: resolveImageUrl(merchant.bannerUrl!),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                    child: Container(
                      width: AppSizes.huge,
                      height: AppSizes.huge,
                      color: AppColors.heroPanel,
                      child: merchant.logoUrl == null
                          ? const AppIcon(
                              AppIcons.storefrontOutlined,
                              color: AppColors.muted,
                            )
                          : NetworkImageBox(
                              url: resolveImageUrl(merchant.logoUrl!),
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant.name,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.extraBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (merchant.tagline != null &&
                            merchant.tagline!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSizes.xs),
                            child: Text(
                              merchant.tagline!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.sm),
                          child: Wrap(
                            spacing: AppSizes.sm,
                            runSpacing: AppSizes.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (merchant.linkedAsParty)
                                _Pill(label: 'CUSTOMER', tone: _PillTone.brand),
                              if (merchant.linkedAsVendor)
                                _Pill(
                                  label: 'SUPPLIER',
                                  tone: _PillTone.accent,
                                ),
                              if (!merchant.isPublished)
                                _Pill(label: 'PRIVATE', tone: _PillTone.muted),
                              if (merchant.rating != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const AppIcon(
                                      AppIcons.starRounded,
                                      size: AppSizes.iconSm,
                                      color: AppColors.warning,
                                    ),
                                    Text(
                                      ' ${merchant.rating!.toStringAsFixed(1)} (${merchant.ratingCount})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppIcon(
                    AppIcons.arrowForwardIosRounded,
                    size: AppSizes.iconSm,
                    color: AppColors.subtle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PillTone { brand, accent, muted }

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});
  final String label;
  final _PillTone tone;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _PillTone.brand => (AppColors.brandSoft, AppColors.brandStrong),
      _PillTone.accent => (AppColors.successSoft, AppColors.success),
      _PillTone.muted => (AppColors.heroPanel, AppColors.muted),
    };
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading state
// ---------------------------------------------------------------------------

/// Renders 3 skeleton merchant cards that mirror [_MerchantCard]'s layout.
class _MerchantListSkeleton extends StatelessWidget {
  const _MerchantListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, _) => const _MerchantCardSkeleton(),
    );
  }
}

/// A single skeleton card whose structure mirrors [_MerchantCard].
class _MerchantCardSkeleton extends StatelessWidget {
  const _MerchantCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner placeholder (aspect ratio 16:6)
          AspectRatio(
            aspectRatio: 16 / 6,
            child: AppShimmerBox(
              width: double.infinity,
              height: double.infinity,
              radius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo placeholder
                AppShimmerBox(
                  width: AppSizes.huge,
                  height: AppSizes.huge,
                  radius: AppSizes.radiusSm,
                ),
                const SizedBox(width: AppSizes.md),
                // Text column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shop name
                      AppShimmerLine(widthFactor: 0.55, height: 14),
                      const SizedBox(height: AppSizes.xs),
                      // Tagline
                      AppShimmerLine(widthFactor: 0.75, height: 11),
                      const SizedBox(height: AppSizes.sm),
                      // Pill row (two pill-shaped blobs)
                      Row(
                        children: [
                          AppShimmerBox(
                            width: 62,
                            height: 20,
                            radius: AppSizes.radiusFull,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          AppShimmerBox(
                            width: 52,
                            height: 20,
                            radius: AppSizes.radiusFull,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.xl),
      children: [
        const SizedBox(height: AppSizes.huge),
        Center(
          child: Container(
            width: AppSizes.productImageSize,
            height: AppSizes.productImageSize,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusLg),
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              AppIcons.storefrontOutlined,
              size: AppSizes.iconHuge,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Text(
          'No linked merchants yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.extraBold,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          "When a shop invites you and you accept, they'll appear here for you to browse.",
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.xl),
      children: [
        const SizedBox(height: AppSizes.huge),
        const AppIcon(
          AppIcons.cloudOffRounded,
          size: AppSizes.iconHuge,
          color: AppColors.muted,
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          'Could not load',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.extraBold,
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.lg),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const AppIcon(AppIcons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
