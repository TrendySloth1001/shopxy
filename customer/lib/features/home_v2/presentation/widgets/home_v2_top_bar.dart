import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/addresses_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/edit_address_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_models.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/notifications_v2/presentation/pages/notifications_v2_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeV2TopBar extends StatelessWidget {
  const HomeV2TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'shop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'xy',
                style: TextStyle(
                  color: Color(0xFFF4F757),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Consumer<AddressesProvider>(
              builder: (context, addr, _) {
                final defaultAddr = addr.defaultAddress;
                final label = defaultAddr == null
                    ? HomeV2StaticData.defaultLocation
                    : 'Deliver to: ${defaultAddr.city} ${defaultAddr.pincode}';
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showAddressSheet(context),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Real unread count from NotificationsProvider — was a
          // hardcoded `3` in the original mock.
          Selector<NotificationsProvider, int>(
            selector: (_, p) => p.unread,
            builder: (_, unread, _) => _TopBarIcon(
              icon: Icons.notifications_none_rounded,
              count: unread,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsV2Page()),
              ),
            ),
          ),
        ],
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
      width: 26,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          if (count != null && count! > 0)
            Positioned(
              right: -4,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F757),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.brand, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.black,
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
