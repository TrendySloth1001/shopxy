import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_invoices_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class MyShopsPage extends StatefulWidget {
  const MyShopsPage({super.key});

  @override
  State<MyShopsPage> createState() => _MyShopsPageState();
}

class _MyShopsPageState extends State<MyShopsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopsProvider>().loadShops();
      context.read<NotificationsProvider>().loadIncoming(status: 'PENDING');
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShopsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myShops),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: p.loadShops,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: p.loadShops,
        color: AppColors.brand,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _PendingInviteCallout(),
            if (p.isLoading && p.shops.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSizes.xxxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (p.error != null && p.shops.isEmpty)
              _ErrorBlock(error: p.error!, onRetry: p.loadShops)
            else if (p.shops.isEmpty)
              const _EmptyShops()
            else ...[
              const SizedBox(height: AppSizes.sm),
              for (final s in p.shops) _ShopTile(shop: s),
              const SizedBox(height: AppSizes.huge),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop});
  final LinkedShop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isParty = shop.role == ShopRole.party;
    final accent = isParty ? AppColors.accentRose : AppColors.accentIndigo;
    final accentSoft = isParty ? AppColors.accentRoseSoft : AppColors.accentIndigoSoft;
    final roleLabel = isParty ? AppStrings.roleCustomer : AppStrings.roleSupplier;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ShopInvoicesPage(shop: shop)),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: ShapeDecoration(
                color: accentSoft,
                shape: AppShapes.squircle(AppSizes.radiusMd),
              ),
              alignment: Alignment.center,
              child: Text(
                shop.name.isEmpty ? '?' : shop.name[0].toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: ShapeDecoration(
                          color: accentSoft,
                          shape: AppShapes.squircle(AppSizes.radiusFull),
                        ),
                        child: Text(
                          roleLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          shop.invoiceCount == 0
                              ? 'No invoices yet'
                              : '${shop.invoiceCount} ${shop.invoiceCount == 1 ? "invoice" : "invoices"}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _EmptyShops extends StatelessWidget {
  const _EmptyShops();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xxxl),
      child: Column(
        children: [
          Container(
            width: 220,
            height: 160,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusLg),
            ),
            child: const Icon(Icons.storefront_outlined,
                size: 48, color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.xl),
          Text(
            AppStrings.noShopsTitle,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            AppStrings.noShopsHint,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xxl),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
          const SizedBox(height: AppSizes.sm),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: AppSizes.md),
          FilledButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}

class _PendingInviteCallout extends StatelessWidget {
  const _PendingInviteCallout();

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsProvider>();
    final pending = n.pendingIncoming;
    if (pending.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final first = pending.first;
    final shopName = first.fromShopName ?? first.fromUserName ?? 'A shop';
    final extra = pending.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        onTap: () => DefaultTabController.of(context).animateTo(1),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: ShapeDecoration(
            color: AppColors.brandSoft,
            shape: AppShapes.squircle(
              AppSizes.radiusLg,
              side: const BorderSide(color: AppColors.brand, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.mark_email_unread_rounded,
                    color: AppColors.white, size: 18),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have a pending invitation',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.brandStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      extra > 0
                          ? '$shopName and $extra other${extra == 1 ? "" : "s"} are waiting for your reply.'
                          : '$shopName wants to add you. Tap to review.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.brandStrong),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.brandStrong),
            ],
          ),
        ),
      ),
    );
  }
}
