import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/invitations_page.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_sections_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class MyShopsPage extends StatefulWidget {
  const MyShopsPage({super.key});

  @override
  State<MyShopsPage> createState() => _MyShopsPageState();
}

enum _RoleFilter { all, customer, supplier }

class _MyShopsPageState extends State<MyShopsPage> {
  _RoleFilter _filter = _RoleFilter.all;

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
    final unread = context.select<NotificationsProvider, int>(
      (n) => n.pendingIncoming.length,
    );

    final sorted = [...p.shops]
      ..sort((a, b) {
        final aT = a.lastInvoiceAt;
        final bT = b.lastInvoiceAt;
        if (aT == null && bT == null) return a.name.compareTo(b.name);
        if (aT == null) return 1;
        if (bT == null) return -1;
        return bT.compareTo(aT);
      });

    final visible = sorted.where(_matchesFilter).toList(growable: false);
    final partyCount = sorted.where((s) => s.role == ShopRole.party).length;
    final supplierCount = sorted.length - partyCount;
    final showFilter = partyCount > 0 && supplierCount > 0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: p.loadShops,
          color: AppColors.brand,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _HeroHeader(
                count: sorted.length,
                isLoading: p.isLoading && sorted.isEmpty,
              ),
              if (p.isLoading && sorted.isEmpty)
                const _SkeletonList()
              else if (p.error != null && sorted.isEmpty)
                _ErrorBlock(error: p.error!, onRetry: p.loadShops)
              else if (sorted.isEmpty)
                const _EmptyShops()
              else ...[
                if (unread > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.lg,
                      AppSizes.md,
                      AppSizes.lg,
                      0,
                    ),
                    child: _InvitesBanner(
                      count: unread,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InvitationsPage(),
                        ),
                      ),
                    ),
                  ),
                if (showFilter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.lg,
                      AppSizes.md,
                      AppSizes.lg,
                      0,
                    ),
                    child: _RoleFilterChips(
                      filter: _filter,
                      onChanged: (f) => setState(() => _filter = f),
                      partyCount: partyCount,
                      supplierCount: supplierCount,
                    ),
                  ),
                const SizedBox(height: AppSizes.md),
                for (final s in visible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.lg,
                      0,
                      AppSizes.lg,
                      AppSizes.md,
                    ),
                    child: _ShopCard(shop: s),
                  ),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                      vertical: AppSizes.xl,
                    ),
                    child: Center(
                      child: Text(
                        _filter == _RoleFilter.customer
                            ? 'No customer links yet.'
                            : 'No supplier links yet.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.huge),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _matchesFilter(LinkedShop s) {
    return switch (_filter) {
      _RoleFilter.all => true,
      _RoleFilter.customer => s.role == ShopRole.party,
      _RoleFilter.supplier => s.role == ShopRole.vendor,
    };
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.count, required this.isLoading});
  final int count;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.hairline, width: 0.6),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (Navigator.of(context).canPop())
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: _HeaderBack(
              key: const Key('merchants-back'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ),
          Text(
            'YOUR MERCHANTS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Merchants',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            isLoading
                ? 'Loading your linked merchants…'
                : count == 0
                ? 'Shops that have linked you appear here.'
                : '$count linked ${count == 1 ? 'merchant' : 'merchants'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBack extends StatelessWidget {
  const _HeaderBack({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline, width: 0.8),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: onTap,
        child: const SizedBox(
          width: AppSizes.avatarSm,
          height: AppSizes.avatarSm,
          child: AppIcon(
            AppIcons.arrowBackRounded,
            color: AppColors.black,
            size: AppSizes.iconMd,
          ),
        ),
      ),
    );
  }
}

class _InvitesBanner extends StatelessWidget {
  const _InvitesBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        decoration: ShapeDecoration(
          color: AppColors.brandSoft,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.brand, width: 0.8),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.xxl,
              height: AppSizes.xxl,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const AppIcon(
                AppIcons.markEmailUnreadRounded,
                color: AppColors.white,
                size: AppSizes.iconSm,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                count == 1
                    ? '1 pending invitation'
                    : '$count pending invitations',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.brandStrong,
              size: AppSizes.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleFilterChips extends StatelessWidget {
  const _RoleFilterChips({
    required this.filter,
    required this.onChanged,
    required this.partyCount,
    required this.supplierCount,
  });
  final _RoleFilter filter;
  final ValueChanged<_RoleFilter> onChanged;
  final int partyCount;
  final int supplierCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip(
          label: 'All',
          selected: filter == _RoleFilter.all,
          onTap: () => onChanged(_RoleFilter.all),
        ),
        const SizedBox(width: AppSizes.xs),
        _Chip(
          label: 'Customer · $partyCount',
          selected: filter == _RoleFilter.customer,
          onTap: () => onChanged(_RoleFilter.customer),
        ),
        const SizedBox(width: AppSizes.xs),
        _Chip(
          label: 'Supplier · $supplierCount',
          selected: filter == _RoleFilter.supplier,
          onTap: () => onChanged(_RoleFilter.supplier),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: ShapeDecoration(
          color: selected ? AppColors.brand : AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusFull,
            side: BorderSide(
              color: selected ? AppColors.brand : AppColors.hairline,
              width: 0.6,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? AppColors.white : AppColors.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});
  final LinkedShop shop;

  @override
  Widget build(BuildContext context) {
    final money = AppFormat.inr;
    final displayName = shop.shopName ?? shop.name;
    final isParty = shop.role == ShopRole.party;
    final roleLabel = isParty
        ? AppStrings.roleCustomer
        : AppStrings.roleSupplier;

    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: const BorderSide(color: AppColors.hairline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ShopSectionsPage(shop: shop)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardBanner(bannerUrl: shop.shopBannerUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                0,
                AppSizes.md,
                AppSizes.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShopLogo(
                          logoUrl: shop.shopLogoUrl,
                          fallbackInitial: _initial(displayName),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSizes.xxl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.black,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        height: 1.2,
                                      ),
                                ),
                                const SizedBox(height: AppSizes.xs),
                                Row(
                                  children: [
                                    _RolePill(label: roleLabel),
                                    const SizedBox(width: AppSizes.sm),
                                    Text(
                                      '·',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.disabled,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(width: AppSizes.sm),
                                    Flexible(
                                      child: Text(
                                        shop.invoiceCount == 0
                                            ? 'No invoices yet'
                                            : '${shop.invoiceCount} ${shop.invoiceCount == 1 ? 'invoice' : 'invoices'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.muted,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -16),
                    child: _ActivityRow(shop: shop, money: money),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initial(String name) {
    if (name.trim().isEmpty) return '?';
    return name.trim().substring(0, 1).toUpperCase();
  }
}

class _CardBanner extends StatelessWidget {
  const _CardBanner({required this.bannerUrl});
  final String? bannerUrl;

  @override
  Widget build(BuildContext context) {
    final hasBanner = bannerUrl != null && bannerUrl!.isNotEmpty;
    return SizedBox(
      height: 78,
      child: hasBanner
          ? Stack(
              children: [
                Positioned.fill(
                  child: NetworkImageBox(url: resolveImageUrl(bannerUrl!)),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.black.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandSoft, AppColors.heroPanel],
                ),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: AppSizes.lg),
              child: const AppIcon(
                AppIcons.storefrontRounded,
                color: AppColors.brand,
                size: AppSizes.iconXl,
              ),
            ),
    );
  }
}

class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.logoUrl, required this.fallbackInitial});
  final String? logoUrl;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: AppSizes.avatarMd,
      height: AppSizes.avatarMd,
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.all(AppSizes.xs),
      child: ClipRRect(
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
        child: hasLogo
            ? NetworkImageBox(url: resolveImageUrl(logoUrl!))
            : Container(
                color: AppColors.brandSoft,
                alignment: Alignment.center,
                child: Text(
                  fallbackInitial,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.brand,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.shop, required this.money});
  final LinkedShop shop;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    final lastAt = shop.lastInvoiceAt;
    final hasActivity = lastAt != null;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              AppIcon(
                hasActivity
                    ? AppIcons.receiptLongRounded
                    : AppIcons.accessTimeRounded,
                size: AppSizes.iconSm,
                color: AppColors.muted,
              ),
              const SizedBox(width: AppSizes.xs),
              Flexible(
                child: Text(
                  hasActivity
                      ? 'Last invoice · ${_formatDate(lastAt)}'
                            '${shop.lastInvoiceTotal != null ? ' · ${money.format(shop.lastInvoiceTotal)}' : ''}'
                      : 'No activity yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: AppSizes.xxl,
          height: AppSizes.xxl,
          decoration: const BoxDecoration(
            color: AppColors.heroPanel,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const AppIcon(
            AppIcons.arrowForwardRounded,
            color: AppColors.black,
            size: AppSizes.iconSm,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (now.year == t.year) return DateFormat('d MMM').format(t);
    return DateFormat('d MMM yyyy').format(t);
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: Column(
        children: List.generate(3, (_) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.md),
            child: Container(
              height: 168,
              decoration: ShapeDecoration(
                color: AppColors.white,
                shape: AppShapes.squircle(
                  AppSizes.radiusLg,
                  side: const BorderSide(color: AppColors.hairline, width: 0.8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 78,
                    decoration: const BoxDecoration(color: AppColors.heroPanel),
                  ),
                  const SizedBox(height: AppSizes.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                    ),
                    child: Container(
                      width: 140,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.heroPanel,
                        borderRadius: AppShapes.squircleRadius(
                          AppSizes.radiusSm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                    ),
                    child: Container(
                      width: 200,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.heroPanel,
                        borderRadius: AppShapes.squircleRadius(
                          AppSizes.radiusSm,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EmptyShops extends StatelessWidget {
  const _EmptyShops();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xl,
        AppSizes.huge,
        AppSizes.xl,
        AppSizes.xl,
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: AppColors.brandSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              AppIcons.storefrontOutlined,
              size: AppSizes.iconXl,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'No linked merchants yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Order from a shop, or accept an invitation, and it appears '
            'here with all its invoices.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _PrimaryCta(
            label: 'View invitations',
            icon: AppIcons.markEmailUnreadRounded,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const InvitationsPage())),
          ),
        ],
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final AppIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, color: AppColors.white, size: AppSizes.iconSm),
              const SizedBox(width: AppSizes.sm),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xl,
        AppSizes.huge,
        AppSizes.xl,
        AppSizes.xl,
      ),
      child: Column(
        children: [
          Container(
            width: AppSizes.massive,
            height: AppSizes.massive,
            decoration: const BoxDecoration(
              color: AppColors.errorSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const AppIcon(
              AppIcons.cloudOffOutlined,
              color: AppColors.error,
              size: AppSizes.iconXl,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            "Couldn't load your merchants",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _PrimaryCta(
            label: AppStrings.retry,
            icon: AppIcons.refreshRounded,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}
