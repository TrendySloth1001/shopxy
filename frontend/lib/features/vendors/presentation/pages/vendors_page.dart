import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/notifications/presentation/pages/send_invite_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendor_detail_page.dart';
import 'package:shopxy/features/vendors/presentation/providers/vendors_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/indian.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

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
  Invitation? _inviteFor(String vendorId, List<Invitation> outgoing) {
    for (final i in outgoing) {
      if (i.linkType == InviteLinkType.vendor && i.vendorId == vendorId) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<VendorsProvider>();
    final outgoing = context.watch<NotificationsProvider>().outgoing;
    final canManage = context.select<AuthProvider, bool>(
      (a) => a.user?.canManage('vendors') ?? false,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.vendorsTitle,
        actions: [
          AccessReloadButton(
            onReload: () => provider.loadVendors(refresh: true),
          ),
          LockedIconButton(
            allowed: canManage,
            icon: AppIcons.addRounded,
            tooltip: l10n.vendorsAddVendor,
            what: 'add vendors',
            onPressed: () => _showVendorSheet(context),
          ),
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                0,
              ),
              child: AppSearchBar(
                hint: l10n.vendorsSearchHint,
                onChanged: context.read<VendorsProvider>().updateSearch,
              ),
            ),
            Expanded(
              child: provider.isLoading && provider.vendors.isEmpty
                  ? const _VendorListSkeleton()
                  : provider.error != null && provider.vendors.isEmpty
                  ? AppErrorView(
                      onRetry: () => context
                          .read<VendorsProvider>()
                          .loadVendors(refresh: true),
                    )
                  : provider.vendors.isEmpty
                  ? EmptyState.line(
                      kind: LineArt.vendors,
                      title: l10n.vendorsEmptyTitle,
                      subtitle: l10n.vendorsEmptyHint,
                      action: MaybeLocked(
                        allowed: canManage,
                        what: 'add vendors',
                        child: AppButton.primary(
                          label: l10n.vendorsAddVendor,
                          icon: AppIcons.addRounded,
                          onPressed: () => _showVendorSheet(context),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => context
                          .read<VendorsProvider>()
                          .loadVendors(refresh: true),
                      color: AppColors.black,
                      backgroundColor: AppColors.surface,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.sm,
                          AppSizes.lg,
                          AppSizes.sm,
                        ),
                        itemCount: provider.vendors.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.sm),
                        itemBuilder: (context, i) {
                          final v = provider.vendors[i];
                          return _VendorTile(
                            vendor: v,
                            invite: _inviteFor(v.id, outgoing),
                            onTap: () => _openDetail(context, v),
                            onEdit: () => _showVendorSheet(context, vendor: v),
                            onDelete: () => _confirmDelete(context, v),
                            onInvite: () => _openInvite(context, v),
                            onCancelInvite: (id) => _cancelInvite(context, id),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
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
      backgroundColor: AppColors.surface,
      builder: (_) => VendorFormSheet(vendor: vendor),
    );
  }

  Future<void> _openInvite(BuildContext context, Vendor v) async {
    final notifs = context.read<NotificationsProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SendInvitePage(initialVendor: v)),
    );
    // Refresh status chips after the send sheet closes. The provider
    // reference was captured before the await so we don't reach back
    // into a possibly-disposed BuildContext.
    if (mounted) notifs.loadOutgoing();
  }

  Future<void> _cancelInvite(BuildContext context, String invitationId) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.vendorsCancelInviteTitle,
      message: l10n.vendorsCancelInviteMessage,
      confirmLabel: l10n.vendorsConfirm,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<NotificationsProvider>().cancel(invitationId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.vendorsInviteCancelled)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, Vendor vendor) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.vendorsDeleteVendor,
      message: '${l10n.vendorsDeleteVendorConfirm} "${vendor.name}"?',
      confirmLabel: l10n.vendorsDelete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<VendorsProvider>().deleteVendor(vendor.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.vendorsVendorDeleted)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
  final ValueChanged<String> onCancelInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
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
                      style: theme.textTheme.titleSmall?.semibold,
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
                      runSpacing: AppSizes.xs,
                      children: [
                        AppStatusBadge(
                          label:
                              '${vendor.transactionCount} ${l10n.vendorsTxnsUnit}',
                          icon: AppIcons.swapVertRounded,
                          dense: true,
                        ),
                        AppStatusBadge(
                          label:
                              '${vendor.invoiceCount} ${l10n.vendorsInvoicesUnit}',
                          icon: AppIcons.receiptOutlined,
                          dense: true,
                        ),
                        if (invite != null) _InviteChip(invite: invite!),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: AppIcon(AppIcons.moreVertRounded, color: AppColors.muted),
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
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon(AppIcons.editOutlined),
              title: Text(l10n.vendorsEdit),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            // Linked vendors don't get a re-invite affordance — the
            // chip on the tile already signals "Linked" and re-sending
            // wouldn't change anything.
            if (invite?.isAccepted == true)
              ListTile(
                leading: AppIcon(
                  AppIcons.verifiedRounded,
                  color: AppColors.success,
                ),
                title: Text(
                  l10n.vendorsAlreadyLinked,
                  style: TextStyle(color: AppColors.success),
                ),
                subtitle: Text(
                  invite!.toEmail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                enabled: false,
              )
            else if (invite == null || !invite!.isPending) ...[
              ListTile(
                leading: AppIcon(
                  AppIcons.personAddAlt1Outlined,
                  color: AppColors.brandStrong,
                ),
                enabled: _canInvite,
                title: Text(
                  l10n.vendorsInviteToShopxy,
                  style: TextStyle(color: AppColors.brandStrong),
                ),
                subtitle: _canInvite
                    ? Text(
                        vendor.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      )
                    : Text(
                        l10n.vendorsAddEmailFirst,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                onTap: () {
                  Navigator.pop(context);
                  onInvite();
                },
              ),
            ] else
              ListTile(
                leading: AppIcon(
                  AppIcons.cancelScheduleSendOutlined,
                  color: AppColors.warning,
                ),
                title: Text(
                  l10n.vendorsCancelInvitation,
                  style: TextStyle(color: AppColors.warning),
                ),
                subtitle: Text(
                  '${l10n.vendorsSentTo} ${invite!.toEmail}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  onCancelInvite(invite!.id);
                },
              ),
            ListTile(
              leading: AppIcon(
                AppIcons.deleteOutlineRounded,
                color: AppColors.error,
              ),
              title: Text(
                l10n.vendorsDelete,
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
    final l10n = AppLocalizations.of(context);
    final (label, icon, fg, bg) = switch (invite.status) {
      InviteStatus.pending => (
        l10n.vendorsInviteStatusInvited,
        AppIcons.markEmailUnreadOutlined,
        AppColors.brandStrong,
        AppColors.brandSoft,
      ),
      InviteStatus.accepted => (
        l10n.vendorsInviteStatusLinked,
        AppIcons.verifiedRounded,
        AppColors.success,
        AppColors.successSoft,
      ),
      InviteStatus.declined => (
        l10n.vendorsInviteStatusDeclined,
        AppIcons.cancelOutlined,
        AppColors.muted,
        AppColors.heroPanel,
      ),
      InviteStatus.cancelled => (
        l10n.vendorsInviteStatusCancelled,
        AppIcons.cancelScheduleSendOutlined,
        AppColors.muted,
        AppColors.heroPanel,
      ),
      InviteStatus.expired => (
        l10n.vendorsInviteStatusExpired,
        AppIcons.timerOffOutlined,
        AppColors.error,
        AppColors.errorSoft,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSizes.md, color: fg),
          const SizedBox(width: AppSizes.xs),
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

// ---------------------------------------------------------------------------
// Skeleton loading state — mirrors _VendorTile layout
// ---------------------------------------------------------------------------

class _VendorListSkeleton extends StatelessWidget {
  const _VendorListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (context, index) => const _VendorTileSkeleton(),
    );
  }
}

class _VendorTileSkeleton extends StatelessWidget {
  const _VendorTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar placeholder — circular
          AppShimmerBox(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            radius: AppSizes.avatarSm / 2,
          ),
          const SizedBox(width: AppSizes.md),
          // Text + badge column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor name line
                AppShimmerLine(widthFactor: 0.55, height: 13),
                const SizedBox(height: AppSizes.xs),
                // Phone / GSTIN line
                AppShimmerLine(widthFactor: 0.40, height: 11),
                const SizedBox(height: AppSizes.sm),
                // Status badge row
                Row(
                  children: [
                    AppShimmerBox(
                      width: 64,
                      height: 20,
                      radius: AppSizes.radiusFull,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    AppShimmerBox(
                      width: 72,
                      height: 20,
                      radius: AppSizes.radiusFull,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action icon placeholder
          AppShimmerBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            radius: AppSizes.iconMd / 2,
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
  late final TextEditingController _city;
  late final TextEditingController _pinCode;
  late final TextEditingController _panNumber;
  late final TextEditingController _gstin;
  String? _stateCode;

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
    _city = TextEditingController(text: v?.city ?? '');
    _pinCode = TextEditingController(text: v?.pinCode ?? '');
    _panNumber = TextEditingController(text: v?.panNumber ?? '');
    _gstin = TextEditingController(text: v?.gstin ?? '');
    _stateCode = v?.stateCode;
  }

  @override
  void dispose() {
    _name.dispose();
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    _pinCode.dispose();
    _panNumber.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<VendorsProvider>();
      final stateName = IndianStates.stateNameFromCode(_stateCode);
      if (isEditing) {
        await provider.updateVendor(
          widget.vendor!.id,
          name: _name.text,
          contactName: _contactName.text,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
          city: _city.text,
          state: stateName ?? '',
          stateCode: _stateCode ?? '',
          pinCode: _pinCode.text,
          panNumber: _panNumber.text.toUpperCase(),
          gstin: _gstin.text.toUpperCase(),
        );
      } else {
        await provider.createVendor(
          name: _name.text,
          contactName: _contactName.text.isNotEmpty ? _contactName.text : null,
          phone: _phone.text.isNotEmpty ? _phone.text : null,
          email: _email.text.isNotEmpty ? _email.text : null,
          address: _address.text.isNotEmpty ? _address.text : null,
          city: _city.text.isNotEmpty ? _city.text : null,
          state: stateName,
          stateCode: _stateCode,
          pinCode: _pinCode.text.isNotEmpty ? _pinCode.text : null,
          panNumber: _panNumber.text.isNotEmpty
              ? _panNumber.text.toUpperCase()
              : null,
          gstin: _gstin.text.isNotEmpty ? _gstin.text.toUpperCase() : null,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                isEditing ? l10n.vendorsEditVendor : l10n.vendorsAddVendor,
                style: Theme.of(context).textTheme.titleLarge?.bold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.lg),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l10n.vendorsVendorName),
                validator: (v) => v == null || v.trim().isEmpty
                    ? l10n.vendorsFieldRequired
                    : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _contactName,
                decoration: InputDecoration(labelText: l10n.vendorsContactName),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      decoration: InputDecoration(labelText: l10n.vendorsPhone),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextFormField(
                      controller: _email,
                      decoration: InputDecoration(labelText: l10n.vendorsEmail),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gstin,
                      decoration: InputDecoration(labelText: l10n.vendorsGstin),
                      textCapitalization: TextCapitalization.characters,
                      validator: IndianValidators.gstin,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextFormField(
                      controller: _panNumber,
                      decoration: const InputDecoration(labelText: 'PAN'),
                      textCapitalization: TextCapitalization.characters,
                      validator: IndianValidators.pan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              TextFormField(
                controller: _address,
                decoration: InputDecoration(labelText: l10n.vendorsAddress),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: InputDecoration(labelText: l10n.vendorsCity),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextFormField(
                      controller: _pinCode,
                      decoration: InputDecoration(
                        labelText: l10n.vendorsPinCode,
                      ),
                      keyboardType: TextInputType.number,
                      validator: IndianValidators.pincode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              DropdownButtonFormField<String>(
                initialValue: _stateCode,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.vendorsState),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.vendorsStateSelect),
                  ),
                  for (final s in IndianStates.all)
                    DropdownMenuItem<String>(
                      value: s.code,
                      child: Text('${s.code} — ${s.name}'),
                    ),
                ],
                onChanged: (v) => setState(() => _stateCode = v),
              ),
              const SizedBox(height: AppSizes.xl),
              AppButton.primary(
                label: l10n.vendorsSave,
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
