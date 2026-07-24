import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/edit_address_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

/// Manage delivery addresses. Reached from the home top-bar
/// location chip and from the profile screen. The default flag
/// is enforced server-side via a partial unique index, so the UI
/// just exposes the toggle.
class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AddressesProvider>().load();
    });
  }

  Future<void> _add(BuildContext context) async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditAddressPage()));
    if (created == true && context.mounted) {
      showAppSnackbar(
        context,
        message: 'Address saved',
        tone: AppSnackbarTone.success,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AddressesProvider provider,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this address?'),
        content: const Text(
          'You can add it again later, but any in-flight order is already tied to '
          'the existing snapshot — it won\'t be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AddressesProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        title: const Text('Delivery addresses'),
      ),
      body: RefreshIndicator(
        onRefresh: () => p.load(),
        child: p.isLoading && p.items.isEmpty
            ? const _AddressesLoadingSkeleton()
            : p.items.isEmpty
            ? _Empty(onAdd: () => _add(context))
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                children: [
                  for (final a in p.items)
                    _AddressTile(
                      address: a,
                      onDefault: () => p.setDefault(a.id),
                      onDelete: () => _confirmDelete(context, p, a.id),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const AppIcon(AppIcons.add),
        label: const Text('Add address'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets (loading state)
// ---------------------------------------------------------------------------

class _AddressesLoadingSkeleton extends StatelessWidget {
  const _AddressesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _AddressTileSkeleton(),
        _AddressTileSkeleton(),
        _AddressTileSkeleton(),
      ],
    );
  }
}

class _AddressTileSkeleton extends StatelessWidget {
  const _AddressTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          // Label / title row
          AppShimmerLine(widthFactor: 0.35, height: 14),
          SizedBox(height: AppSizes.xs),
          // Full name
          AppShimmerLine(widthFactor: 0.55, height: 13),
          SizedBox(height: AppSizes.xs),
          // Address one-liner
          AppShimmerLine(widthFactor: 0.85, height: 13),
          SizedBox(height: AppSizes.xs),
          // Phone number
          AppShimmerLine(widthFactor: 0.4, height: 12),
          SizedBox(height: AppSizes.sm),
          // Action row (button area)
          AppShimmerBox(width: 120, height: 32, radius: AppSizes.radiusSm),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AddressTile extends StatelessWidget {
  const _AddressTile({
    required this.address,
    required this.onDefault,
    required this.onDelete,
  });
  final UserAddress address;
  final VoidCallback onDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                address.label ?? address.fullName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              if (address.isDefault)
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
                    'DEFAULT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            address.fullName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            address.oneLine,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          Text(
            address.phone,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              if (!address.isDefault)
                TextButton.icon(
                  onPressed: onDefault,
                  icon: const AppIcon(
                    AppIcons.checkCircleOutline,
                    size: AppSizes.iconSm,
                  ),
                  label: const Text('Set as default'),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                icon: const AppIcon(
                  AppIcons.deleteOutline,
                  color: AppColors.error,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Center(
          child: AppIcon(
            AppIcons.locationOffOutlined,
            size: AppSizes.iconHuge,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Center(
          child: Text(
            'No addresses saved yet',
            style: Theme.of(context).textTheme.titleMedium?.bold,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Center(
          child: Text(
            'Add one to speed up checkout.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Center(
          child: AppButton.primary(
            label: 'Add address',
            onPressed: onAdd,
            icon: AppIcons.add,
          ),
        ),
      ],
    );
  }
}
