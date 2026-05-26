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
            ? const Center(child: CircularProgressIndicator())
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
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.md),
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
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    child: Container(
                      width: 52,
                      height: 52,
                      color: AppColors.heroPanel,
                      child: merchant.logoUrl == null
                          ? const Icon(Icons.storefront_outlined,
                              color: AppColors.muted)
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
                          style: const TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (merchant.tagline != null && merchant.tagline!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              merchant.tagline!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (merchant.linkedAsParty)
                                _Pill(label: 'CUSTOMER', tone: _PillTone.brand),
                              if (merchant.linkedAsVendor)
                                _Pill(label: 'SUPPLIER', tone: _PillTone.accent),
                              if (!merchant.isPublished)
                                _Pill(label: 'PRIVATE', tone: _PillTone.muted),
                              if (merchant.rating != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 12, color: AppColors.warning),
                                    Text(
                                      ' ${merchant.rating!.toStringAsFixed(1)} (${merchant.ratingCount})',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 11,
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
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppColors.subtle),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

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
            width: 120,
            height: 120,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusLg),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.storefront_outlined,
              size: 56,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        const Text(
          'No linked merchants yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.black,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "When a shop invites you and you accept, they'll appear here for you to browse.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
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
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.muted),
        const SizedBox(height: AppSizes.md),
        const Text(
          'Could not load',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: AppSizes.lg),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }
}
