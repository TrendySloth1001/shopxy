import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/features/vendors/presentation/providers/vendors_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<VendorsProvider>().loadVendors();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VendorsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navVendors),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: AppStrings.addVendor,
            onPressed: () => _showVendorSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: AppSearchBar(
              hint: AppStrings.searchVendors,
              onChanged: context.read<VendorsProvider>().updateSearch,
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.vendors.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && provider.vendors.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: AppStrings.error,
                      action: TextButton(
                        onPressed: () => context
                            .read<VendorsProvider>()
                            .loadVendors(refresh: true),
                        child: const Text(AppStrings.retry),
                      ),
                    ),
                  )
                : provider.vendors.isEmpty
                ? EmptyState(
                    icon: Icons.business_outlined,
                    title: AppStrings.noVendors,
                    subtitle: AppStrings.noVendorsHint,
                    action: FilledButton.icon(
                      onPressed: () => _showVendorSheet(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(AppStrings.addVendor),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => context
                        .read<VendorsProvider>()
                        .loadVendors(refresh: true),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      itemCount: provider.vendors.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSizes.sm),
                      itemBuilder: (context, i) => _VendorTile(
                        vendor: provider.vendors[i],
                        onEdit: () => _showVendorSheet(
                          context,
                          vendor: provider.vendors[i],
                        ),
                        onDelete: () =>
                            _confirmDelete(context, provider.vendors[i]),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showVendorSheet(BuildContext context, {Vendor? vendor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _VendorFormSheet(vendor: vendor),
    );
  }

  void _confirmDelete(BuildContext context, Vendor vendor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteVendor),
        content: Text('${AppStrings.deleteVendorConfirm} "${vendor.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<VendorsProvider>().deleteVendor(vendor.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(AppStrings.vendorDeleted)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({
    required this.vendor,
    required this.onEdit,
    required this.onDelete,
  });
  final Vendor vendor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  vendor.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (vendor.phone != null)
                      Text(vendor.phone!, style: theme.textTheme.bodySmall),
                    if (vendor.gstin != null)
                      Text(
                        'GSTIN: ${vendor.gstin}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.swap_vert_rounded,
                          label: '${vendor.transactionCount} txns',
                        ),
                        const SizedBox(width: AppSizes.sm),
                        _StatChip(
                          icon: Icons.receipt_outlined,
                          label: '${vendor.invoiceCount} invoices',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () => _showMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text(AppStrings.edit),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                AppStrings.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorFormSheet extends StatefulWidget {
  const _VendorFormSheet({this.vendor});
  final Vendor? vendor;

  @override
  State<_VendorFormSheet> createState() => _VendorFormSheetState();
}

class _VendorFormSheetState extends State<_VendorFormSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  late final TextEditingController _name;
  late final TextEditingController _contactName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _gstin;

  bool get isEditing => widget.vendor != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    _name = TextEditingController(text: v?.name ?? '');
    _contactName = TextEditingController(text: v?.contactName ?? '');
    _phone = TextEditingController(text: v?.phone ?? '');
    _email = TextEditingController(text: v?.email ?? '');
    _address = TextEditingController(text: v?.address ?? '');
    _gstin = TextEditingController(text: v?.gstin ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<VendorsProvider>();
      if (isEditing) {
        await provider.updateVendor(
          widget.vendor!.id,
          name: _name.text,
          contactName: _contactName.text,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
          gstin: _gstin.text,
        );
      } else {
        await provider.createVendor(
          name: _name.text,
          contactName: _contactName.text.isNotEmpty ? _contactName.text : null,
          phone: _phone.text.isNotEmpty ? _phone.text : null,
          email: _email.text.isNotEmpty ? _email.text : null,
          address: _address.text.isNotEmpty ? _address.text : null,
          gstin: _gstin.text.isNotEmpty ? _gstin.text : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSizes.lg,
        right: AppSizes.lg,
        top: AppSizes.lg,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? AppStrings.editVendor : AppStrings.addVendor,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSizes.lg),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: AppStrings.vendorName,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? AppStrings.fieldRequired
                    : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _contactName,
                decoration: const InputDecoration(
                  labelText: AppStrings.contactName,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      decoration: const InputDecoration(
                        labelText: AppStrings.phone,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextFormField(
                      controller: _email,
                      decoration: const InputDecoration(
                        labelText: AppStrings.email,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _gstin,
                decoration: const InputDecoration(labelText: AppStrings.gstin),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(
                  labelText: AppStrings.address,
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSizes.xl),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.save),
              ),
              const SizedBox(height: AppSizes.xl),
            ],
          ),
        ),
      ),
    );
  }
}
