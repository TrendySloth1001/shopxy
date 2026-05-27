import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/edit_address_page.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

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
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EditAddressPage()),
    );
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
    int id,
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
            ? const Center(child: CircularProgressIndicator())
            : p.items.isEmpty
                ? _Empty(onAdd: () => _add(context))
                : ListView(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.sm),
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
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
    );
  }
}

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
      margin: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.sm, AppSizes.lg, 0),
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
                style: const TextStyle(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              if (address.isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Text(
                    'DEFAULT',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            address.fullName,
            style: const TextStyle(color: AppColors.black, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            address.oneLine,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          Text(
            address.phone,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              if (!address.isDefault)
                TextButton.icon(
                  onPressed: onDefault,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Set as default'),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
        const Center(child: Icon(Icons.location_off_outlined, size: 56, color: AppColors.muted)),
        const SizedBox(height: AppSizes.md),
        const Center(
          child: Text(
            'No addresses saved yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text(
            'Add one to speed up checkout.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Center(child: AppButton.primary(label: 'Add address', onPressed: onAdd, icon: Icons.add)),
      ],
    );
  }
}
