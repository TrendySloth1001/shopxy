import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/notifications/presentation/pages/send_invite_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendor_detail_page.dart';
import 'package:shopxy/features/vendors/presentation/providers/vendors_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
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
      if (!mounted) return;
      context.read<VendorsProvider>().loadVendors();
      // Pull invite state once so each row can show its status chip.
      // Cheap query — uses (from_user_id, status, created_at DESC) index.
      context.read<NotificationsProvider>().loadOutgoing();
    });
  }

  /// Most recent invitation we've sent for this vendor, if any. PENDING
  /// beats ACCEPTED beats DECLINED — first match wins because outgoing
  /// is already createdAt DESC.
  Invitation? _inviteFor(int vendorId, List<Invitation> outgoing) {
    for (final i in outgoing) {
      if (i.linkType == InviteLinkType.vendor && i.vendorId == vendorId) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VendorsProvider>();
    final outgoing = context.watch<NotificationsProvider>().outgoing;

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
                    ? AppErrorView(
                        onRetry: () => context
                            .read<VendorsProvider>()
                            .loadVendors(refresh: true),
                      )
                    : provider.vendors.isEmpty
                        ? EmptyState.line(
                            kind: LineArt.vendors,
                            title: AppStrings.noVendors,
                            subtitle: AppStrings.noVendorsHint,
                            action: AppButton.primary(
                              label: AppStrings.addVendor,
                              icon: Icons.add_rounded,
                              onPressed: () => _showVendorSheet(context),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => context
                                .read<VendorsProvider>()
                                .loadVendors(refresh: true),
                            color: AppColors.black,
                            backgroundColor: AppColors.white,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.sm,
                              ),
                              itemCount: provider.vendors.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (context, i) {
                                final v = provider.vendors[i];
                                return _VendorTile(
                                  vendor: v,
                                  invite: _inviteFor(v.id, outgoing),
                                  onTap: () => _openDetail(context, v),
                                  onEdit: () =>
                                      _showVendorSheet(context, vendor: v),
                                  onDelete: () => _confirmDelete(context, v),
                                  onInvite: () => _openInvite(context, v),
                                  onCancelInvite: (id) =>
                                      _cancelInvite(context, id),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Vendor v) async {
    // Capture before await so the post-pop refresh doesn't reach back
    // into a possibly-disposed BuildContext.
    final provider = context.read<VendorsProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VendorDetailPage(vendorId: v.id)),
    );
    if (mounted) provider.loadVendors(refresh: true);
  }

  void _showVendorSheet(BuildContext context, {Vendor? vendor}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (_) => VendorFormSheet(vendor: vendor),
    );
  }

  Future<void> _openInvite(BuildContext context, Vendor v) async {
    final notifs = context.read<NotificationsProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendInvitePage(initialVendor: v),
      ),
    );
    // Refresh status chips after the send sheet closes. The provider
    // reference was captured before the await so we don't reach back
    // into a possibly-disposed BuildContext.
    if (mounted) notifs.loadOutgoing();
  }

  Future<void> _cancelInvite(BuildContext context, int invitationId) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Cancel invitation',
      message: 'Cancel this pending invitation? You can send a new one later.',
      confirmLabel: AppStrings.confirm,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<NotificationsProvider>().cancel(invitationId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Vendor vendor) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppStrings.deleteVendor,
      message: '${AppStrings.deleteVendorConfirm} "${vendor.name}"?',
      confirmLabel: AppStrings.delete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<VendorsProvider>().deleteVendor(vendor.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.vendorDeleted)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _VendorTile extends StatelessWidget {
  const _VendorTile({
    required this.onTap,
    required this.vendor,
    required this.invite,
    required this.onEdit,
    required this.onDelete,
    required this.onInvite,
    required this.onCancelInvite,
  });
  final Vendor vendor;
  final Invitation? invite;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onInvite;
  final ValueChanged<int> onCancelInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              AppMonogramAvatar(label: vendor.name),
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
                      Text(
                        vendor.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    if (vendor.gstin != null)
                      Text(
                        'GSTIN: ${vendor.gstin}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    const SizedBox(height: AppSizes.xs),
                    Wrap(
                      spacing: AppSizes.xs,
                      runSpacing: 4,
                      children: [
                        AppStatusBadge(
                          label: '${vendor.transactionCount} txns',
                          icon: Icons.swap_vert_rounded,
                          dense: true,
                        ),
                        AppStatusBadge(
                          label: '${vendor.invoiceCount} invoices',
                          icon: Icons.receipt_outlined,
                          dense: true,
                        ),
                        if (invite != null) _InviteChip(invite: invite!),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                onPressed: () => _showMenu(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canInvite => (vendor.email ?? '').isNotEmpty;

  void _showMenu(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.edit),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            if (invite == null || !invite!.isPending) ...[
              ListTile(
                leading: const Icon(
                  Icons.person_add_alt_1_outlined,
                  color: AppColors.brandStrong,
                ),
                enabled: _canInvite,
                title: const Text(
                  'Invite to Shopxy',
                  style: TextStyle(color: AppColors.brandStrong),
                ),
                subtitle: _canInvite
                    ? Text(vendor.email!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted))
                    : Text('Add an email first',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted)),
                onTap: () {
                  Navigator.pop(context);
                  onInvite();
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.cancel_schedule_send_outlined,
                    color: AppColors.warning),
                title: const Text(
                  'Cancel invitation',
                  style: TextStyle(color: AppColors.warning),
                ),
                subtitle: Text('Sent to ${invite!.toEmail}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted)),
                onTap: () {
                  Navigator.pop(context);
                  onCancelInvite(invite!.id);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                AppStrings.delete,
                style: TextStyle(color: AppColors.error),
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

/// Small status pill that reflects the most recent invitation we've
/// sent for the surrounding contact. Hidden when no invite exists so
/// the tile stays calm for the common case.
class _InviteChip extends StatelessWidget {
  const _InviteChip({required this.invite});
  final Invitation invite;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = switch (invite.status) {
      InviteStatus.pending => (
          'Invited',
          Icons.mark_email_unread_outlined,
          AppColors.brandStrong,
          AppColors.brandSoft,
        ),
      InviteStatus.accepted => (
          'Linked',
          Icons.verified_rounded,
          AppColors.success,
          AppColors.successSoft,
        ),
      InviteStatus.declined => (
          'Declined',
          Icons.cancel_outlined,
          AppColors.muted,
          AppColors.heroPanel,
        ),
      InviteStatus.cancelled => (
          'Cancelled',
          Icons.cancel_schedule_send_outlined,
          AppColors.muted,
          AppColors.heroPanel,
        ),
      InviteStatus.expired => (
          'Expired',
          Icons.timer_off_outlined,
          AppColors.error,
          AppColors.errorSoft,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
        ],
      ),
    );
  }
}

class VendorFormSheet extends StatefulWidget {
  const VendorFormSheet({super.key, this.vendor});
  final Vendor? vendor;

  @override
  State<VendorFormSheet> createState() => VendorFormSheetState();
}

class VendorFormSheetState extends State<VendorFormSheet> {
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
          contactName:
              _contactName.text.isNotEmpty ? _contactName.text : null,
          phone: _phone.text.isNotEmpty ? _phone.text : null,
          email: _email.text.isNotEmpty ? _email.text : null,
          address: _address.text.isNotEmpty ? _address.text : null,
          gstin: _gstin.text.isNotEmpty ? _gstin.text : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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
              Center(
                child: LineIllustration(
                  kind: LineArt.vendors,
                  size: 88,
                  accent: AppColors.brand,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                isEditing ? AppStrings.editVendor : AppStrings.addVendor,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
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
              AppButton.primary(
                label: AppStrings.save,
                onPressed: _save,
                isLoading: _isSaving,
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
              const SizedBox(height: AppSizes.xl),
            ],
          ),
        ),
      ),
    );
  }
}
