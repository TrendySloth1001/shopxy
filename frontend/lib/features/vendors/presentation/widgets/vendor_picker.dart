import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Opens a modal search sheet to pick an existing Vendor or create a new
/// one. Mirrors [showPartyPicker] for the purchase-invoice flow so the
/// user can add a vendor inline without leaving the page.
Future<Vendor?> showVendorPicker(BuildContext context) {
  return showModalBottomSheet<Vendor>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _VendorPickerSheet(),
  );
}

class _VendorPickerSheet extends StatefulWidget {
  const _VendorPickerSheet();

  @override
  State<_VendorPickerSheet> createState() => _VendorPickerSheetState();
}

class _VendorPickerSheetState extends State<_VendorPickerSheet> {
  final _search = TextEditingController();
  List<Vendor> _vendors = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<VendorsRemoteDataSource>();
      final results = await ds.getVendors(
        search: query.isNotEmpty ? query : null,
        limit: 20,
      );
      if (mounted) setState(() => _vendors = results);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addNew() async {
    final created = await showModalBottomSheet<Vendor>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const VendorFormSheet(),
    );
    if (created != null && mounted) {
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = MediaQuery.of(context).size.height * 0.8;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.md),
            Container(
              width: 40,
              height: AppSizes.xs,
              decoration: ShapeDecoration(
                color: AppColors.hairline,
                shape: AppShapes.squircle(AppSizes.radiusXs),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  Text(
                    AppStrings.selectVendor,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  AppButton.ghost(
                    label: AppStrings.newVendor,
                    icon: Icons.add_rounded,
                    onPressed: _addNew,
                    size: AppButtonSize.sm,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: AppStrings.searchVendors,
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: _load,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: _loading && _vendors.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _vendors.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSizes.xl),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      size: AppSizes.iconXl,
                                      color: AppColors.muted,
                                    ),
                                    const SizedBox(height: AppSizes.md),
                                    Text(
                                      AppStrings.noVendors,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: AppSizes.md),
                                    AppButton.primary(
                                      label: AppStrings.addVendor,
                                      icon: Icons.add_rounded,
                                      onPressed: _addNew,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _vendors.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (context, i) {
                                final v = _vendors[i];
                                return ListTile(
                                  leading: AppMonogramAvatar(label: v.name),
                                  title: Text(v.name),
                                  subtitle: Text(v.phone ?? v.contactName ?? '—'),
                                  onTap: () => Navigator.pop(context, v),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
