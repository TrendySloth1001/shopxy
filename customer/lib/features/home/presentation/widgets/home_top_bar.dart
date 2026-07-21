import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/addresses_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/edit_address_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/pending_payments_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

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
              _BrandWordmark(t: t),
              // As the full search bar collapses away on scroll, a broad
              // search field fades in here to fill the freed space. The
              // address isn't surfaced in the collapsed header at all —
              // it's still one tap away via the location row up top when
              // expanded. Expanded keeps the wallet/bell/avatar pinned to
              // the right (acts as a spacer while the field is invisible).
              Expanded(
                child: _CollapsedSearchField(
                  t: t,
                  onTap: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const SearchPage())),
                ),
              ),
              // Pending-payment affordance. Lives up here next to the
              // bell — out of the browse path — so the home feed stays
              // a clean shopping surface. Renders nothing when there's
              // nothing to pay; the badge counts outstanding orders and
              // a tap opens the full list.
              Selector<OrdersProvider, int>(
                selector: (_, p) =>
                    p.orders.where((o) => o.needsOnlinePayment).length,
                builder: (_, pending, _) {
                  if (pending == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSizes.xs),
                    child: _TopBarIcon(
                      icon: AppIcons.accountBalanceWalletOutlined,
                      count: pending,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PendingPaymentsPage(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Selector<NotificationsProvider, int>(
                selector: (_, p) => p.unread,
                builder: (_, unread, _) => _TopBarIcon(
                  icon: AppIcons.notificationsNoneRounded,
                  count: unread,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
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
                // Hint-or-real getter — keeps the profile button's
                // visibility consistent with the bottom-nav layout
                // decision from the very first paint.
                selector: (_, p) => p.hasLinkedParty,
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
                  padding: const EdgeInsets.only(top: AppSizes.sm),
                  child: Consumer<AddressesProvider>(
                    builder: (context, addr, _) {
                      final defaultAddr = addr.defaultAddress;
                      return _LocationPill(
                        line: defaultAddr?.line1,
                        pincode: defaultAddr?.pincode,
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

/// Broad search field that lives in the brand row and fades in as the
/// page scrolls (the full search bar below collapses away at the same
/// time). Sits inside an [Expanded], so at t=0 it's invisible and
/// non-interactive but still reserves the middle width — keeping the
/// wallet/bell/avatar pinned to the right exactly like a [Spacer] would.
///
/// Cycles the same rotating [HomeStaticData.searchHints] as the full
/// search bar, with the matching slide+fade transition, so the two read
/// as one continuous element across the scroll.
class _CollapsedSearchField extends StatefulWidget {
  const _CollapsedSearchField({required this.t, required this.onTap});

  /// 0 = expanded header (field hidden), 1 = fully collapsed (field shown).
  final double t;
  final VoidCallback onTap;

  @override
  State<_CollapsedSearchField> createState() => _CollapsedSearchFieldState();
}

class _CollapsedSearchFieldState extends State<_CollapsedSearchField> {
  int _hintIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(
        () => _hintIndex = (_hintIndex + 1) % HomeStaticData.searchHints.length,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Don't intercept taps across the middle of the header while the
      // field is (near) invisible at the top of the page.
      ignoring: widget.t < 0.5,
      child: Opacity(
        opacity: widget.t.clamp(0.0, 1.0),
        child: Padding(
          padding: const EdgeInsets.only(left: AppSizes.md, right: AppSizes.sm),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              decoration: ShapeDecoration(
                color: AppColors.white,
                shape: AppShapes.squircle(
                  AppSizes.radiusMd,
                  side: const BorderSide(color: AppColors.hairline, width: 0.6),
                ),
              ),
              child: Row(
                children: [
                  const AppIcon(
                    AppIcons.searchRounded,
                    color: AppColors.muted,
                    size: 18,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Text(
                        HomeStaticData.searchHints[_hintIndex],
                        key: ValueKey(_hintIndex),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandWordmark extends StatelessWidget {
  const _BrandWordmark({required this.t});

  /// 0 = expanded (full "shopxy." wordmark), 1 = collapsed (just the
  /// "S" mark). The text portion shrinks + fades away as the header
  /// collapses, freeing width for the search field beside it.
  final double t;

  @override
  Widget build(BuildContext context) {
    final reveal = (1 - t).clamp(0.0, 1.0);
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
          // Placeholder mark — to be replaced with the real logo later.
          child: const AppIcon(
            AppIcons.storefrontRounded,
            color: AppColors.white,
            size: 18,
          ),
        ),
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: reveal,
            child: Opacity(
              opacity: reveal,
              child: const Padding(
                padding: EdgeInsets.only(left: AppSizes.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
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
                    SizedBox(width: AppSizes.xxs),
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationPill extends StatelessWidget {
  const _LocationPill({
    required this.line,
    required this.pincode,
    required this.onTap,
  });

  /// Address line 1 of the default address. Null/empty when no address
  /// is saved — the pill then renders an "Add a delivery address" CTA in
  /// brand colour instead of stamping in a placeholder.
  final String? line;

  /// Pincode of the default address. Pinned at the end of the row so it
  /// stays visible even when a long [line] truncates with an ellipsis.
  final String? pincode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAddress = line != null && line!.isNotEmpty;
    final hasPincode = pincode != null && pincode!.isNotEmpty;
    // Slim, borderless single line — no filled panel. Reads as a light
    // "deliver to <line 1> <pincode> ▾" affordance under the brand row
    // instead of a heavy boxed pill.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            AppIcon(
              hasAddress
                  ? AppIcons.locationOnRounded
                  : AppIcons.addLocationAltOutlined,
              color: AppColors.brand,
              size: 16,
            ),
            const SizedBox(width: 6),
            if (hasAddress) ...[
              const Text(
                'Deliver to  ',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Flexible(
                child: Text(
                  line!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (hasPincode) ...[
                const SizedBox(width: 5),
                Text(
                  pincode!,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ] else
              const Flexible(
                child: Text(
                  'Add a delivery address',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            const SizedBox(width: AppSizes.xxs),
            const AppIcon(
              AppIcons.keyboardArrowDownRounded,
              color: AppColors.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAddressSheet(BuildContext context) async {
  // Saving / picking a delivery address is per-user; a guest tapping
  // the address chip is asking to set up shipping — gate at the door
  // instead of letting them open the sheet, see a "no addresses" empty
  // state, then hit a 401 the moment they tap "Add new".
  final signedIn = await requireAuth(
    context,
    reason: 'Sign in to save delivery addresses and use them at checkout.',
  );
  if (!signedIn || !context.mounted) return;
  // Read provider before showing the sheet; the sheet builds in its
  // own context that still has access via the root MaterialApp tree.
  context.read<AddressesProvider>().load();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusLg),
      ),
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
                width: AppSizes.handleWidth,
                height: AppSizes.handleHeight,
                margin: const EdgeInsets.only(bottom: AppSizes.md),
                decoration: BoxDecoration(
                  color: AppColors.disabled,
                  borderRadius: BorderRadius.circular(AppSizes.radiusXs),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
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
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
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
                            await context.read<AddressesProvider>().setDefault(
                              addr.id,
                            );
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
                    icon: AppIcons.addLocationAltOutlined,
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
                    icon: AppIcons.tuneRounded,
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
            AppIcon(
              selected
                  ? AppIcons.radioButtonChecked
                  : AppIcons.radioButtonUnchecked,
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
                              color: AppColors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSizes.xxs),
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
  final AppIconData icon;
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
            AppIcon(icon, color: AppColors.brand, size: 18),
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
  final AppIconData icon;
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
                  side: const BorderSide(color: AppColors.hairline, width: 0.6),
                ),
              ),
              alignment: Alignment.center,
              child: AppIcon(icon, color: AppColors.black, size: 20),
            ),
            if (count != null && count! > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
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
        selector: (_, a) => (name: a.user?.name, avatarUrl: a.user?.avatarUrl),
        builder: (_, u, _) {
          final hasAvatar = u.avatarUrl != null && u.avatarUrl!.isNotEmpty;
          return Container(
            width: 38,
            height: 38,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(
                AppSizes.radiusMd,
                side: const BorderSide(color: AppColors.hairline, width: 0.6),
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
