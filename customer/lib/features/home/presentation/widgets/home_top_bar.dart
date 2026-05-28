import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/addresses_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/edit_address_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, this.shrink = 0.0});

  /// 0.0 = fully expanded (brand row + location pill below), 1.0 =
  /// fully collapsed (only the brand row, now with compact city +
  /// search substitutes that have faded in beside the bell).
  final double shrink;

  @override
  Widget build(BuildContext context) {
    // Ease the visibility so the compact substitutes finish fading in
    // before the user has scrolled too far — linear `t` would feel
    // sluggish at the top of the curve.
    final t = Curves.easeOut.transform(shrink.clamp(0.0, 1.0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _BrandWordmark(),
              const Spacer(),
              // Compact substitutes fade in (and claim width) as the
              // full-row pill + search bar collapse away below.
              Consumer<AddressesProvider>(
                builder: (context, addr, _) {
                  final defaultAddr = addr.defaultAddress;
                  final city = defaultAddr?.city ?? 'New Delhi';
                  return _CollapsedSlot(
                    t: t,
                    fullWidth: 110,
                    child: _CompactCityChip(
                      city: city,
                      onTap: () => _showAddressSheet(context),
                    ),
                  );
                },
              ),
              _CollapsedSlot(
                t: t,
                fullWidth: 44,
                child: _TopBarIcon(
                  icon: Icons.search_rounded,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchPage()),
                  ),
                ),
              ),
              Selector<NotificationsProvider, int>(
                selector: (_, p) => p.unread,
                builder: (_, unread, _) => _TopBarIcon(
                  icon: Icons.notifications_none_rounded,
                  count: unread,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsPage()),
                  ),
                ),
              ),
              // Profile button moves here when the customer is linked
              // to at least one merchant (shop-side party link). In
              // that layout the bottom nav drops the Profile tab in
              // favour of Merchant, so the affordance lives next to
              // the bell instead. Unlinked customers don't render this
              // — Profile is still reachable via the bottom nav.
              Selector<ShopsProvider, bool>(
                selector: (_, p) =>
                    p.shops.any((s) => s.role == ShopRole.party),
                builder: (_, linked, _) {
                  if (!linked) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: AppSizes.xs),
                    child: _ProfileButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerProfilePage(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          // The location pill collapses (height + opacity + the
          // separator above it) as `t` -> 1. ClipRect ensures the
          // collapsing content doesn't bleed visually.
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: (1 - t).clamp(0.0, 1.0),
              child: Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSizes.md),
                  child: Consumer<AddressesProvider>(
                    builder: (context, addr, _) {
                      final defaultAddr = addr.defaultAddress;
                      final cityLine = defaultAddr == null
                          ? 'New Delhi 110001'
                          : '${defaultAddr.city} ${defaultAddr.pincode}';
                      return _LocationPill(
                        cityLine: cityLine,
                        onTap: () => _showAddressSheet(context),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a brand-row substitute so it claims no width when invisible
/// (at t=0) and full width when fully faded in (at t=1). Using
/// Opacity alone would leave a phantom gap when collapsed.
class _CollapsedSlot extends StatelessWidget {
  const _CollapsedSlot({
    required this.t,
    required this.fullWidth,
    required this.child,
  });
  final double t;
  final double fullWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(right: AppSizes.xs * t),
      child: ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: t,
          child: Opacity(opacity: t, child: child),
        ),
      ),
    );
  }
}

class _CompactCityChip extends StatelessWidget {
  const _CompactCityChip({required this.city, required this.onTap});
  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline, width: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: AppColors.brand,
              size: 14,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: ShapeDecoration(
            color: AppColors.brand,
            shape: AppShapes.squircle(AppSizes.radiusSm),
          ),
          alignment: Alignment.center,
          child: const Text(
            'S',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: const [
            Text(
              'shop',
              style: TextStyle(
                color: AppColors.black,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1,
              ),
            ),
            Text(
              'xy',
              style: TextStyle(
                color: AppColors.brand,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1,
              ),
            ),
            SizedBox(width: 2),
            Text(
              '.',
              style: TextStyle(
                color: AppColors.brand,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.cityLine, required this.onTap});
  final String cityLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm + 2,
        ),
        decoration: ShapeDecoration(
          color: AppColors.heroPanel,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline, width: 0.6),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.brand,
                size: 16,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'DELIVER TO',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.9,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cityLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

void _showAddressSheet(BuildContext context) {
  // Read provider before showing the sheet; the sheet builds in its
  // own context that still has access via the root MaterialApp tree.
  context.read<AddressesProvider>().load();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
    ),
    builder: (_) => const _AddressSheet(),
  );
}

class _AddressSheet extends StatelessWidget {
  const _AddressSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          AppSizes.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.disabled,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Deliver to',
              style: TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Consumer<AddressesProvider>(
              builder: (context, p, _) {
                if (p.isLoading && p.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (p.items.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSizes.lg),
                    child: Text(
                      p.error ?? 'No saved addresses yet.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: p.items.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (_, i) {
                      final addr = p.items[i];
                      return _AddressRow(
                        address: addr,
                        onTap: () async {
                          if (!addr.isDefault) {
                            await context
                                .read<AddressesProvider>()
                                .setDefault(addr.id);
                          }
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    icon: Icons.add_location_alt_outlined,
                    label: 'Add new',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditAddressPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.tune_rounded,
                    label: 'Manage',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AddressesPage(),
                        ),
                      );
                    },
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

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.onTap});
  final UserAddress address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = address.isDefault;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.08)
              : AppColors.heroPanel,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(
              color: selected ? AppColors.brand : Colors.transparent,
              width: 1.4,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.brand : AppColors.muted,
              size: 20,
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.label ?? address.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: AppSizes.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'DEFAULT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address.oneLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
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

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.heroPanel,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.brand, size: 18),
            const SizedBox(width: AppSizes.xs),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  const _TopBarIcon({required this.icon, this.count, this.onTap});
  final IconData icon;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: ShapeDecoration(
                color: AppColors.white,
                shape: AppShapes.squircle(
                  AppSizes.radiusMd,
                  side: const BorderSide(
                    color: AppColors.hairline,
                    width: 0.6,
                  ),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.black, size: 20),
            ),
            if (count != null && count! > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.canvas, width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tappable avatar that opens the customer profile page. Rendered next
/// to the notification bell when the customer is linked to at least
/// one merchant — in that layout the bottom nav drops Profile in
/// favour of Merchant, so this is where the user reaches it.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Selector<AuthProvider, ({String? name, String? avatarUrl})>(
        selector: (_, a) =>
            (name: a.user?.name, avatarUrl: a.user?.avatarUrl),
        builder: (_, u, _) {
          final hasAvatar =
              u.avatarUrl != null && u.avatarUrl!.isNotEmpty;
          return Container(
            width: 38,
            height: 38,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(
                AppSizes.radiusMd,
                side: const BorderSide(
                  color: AppColors.hairline,
                  width: 0.6,
                ),
              ),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: hasAvatar
                  ? NetworkImageBox(url: resolveImageUrl(u.avatarUrl!))
                  : Container(
                      color: AppColors.brandSoft,
                      alignment: Alignment.center,
                      child: Text(
                        _initial(u.name),
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  static String _initial(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim().substring(0, 1).toUpperCase();
  }
}
