import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/notifications/presentation/pages/send_invite_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/pages/party_detail_page.dart';
import 'package:shopxy/features/parties/presentation/providers/parties_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/indian.dart';
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

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key});

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PartiesProvider>().loadParties();
      context.read<NotificationsProvider>().loadOutgoing();
    });
  }

  /// Most recent invitation we've sent for this party, if any.
  /// Outgoing is already createdAt DESC so first match wins.
  Invitation? _inviteFor(int partyId, List<Invitation> outgoing) {
    for (final i in outgoing) {
      if (i.linkType == InviteLinkType.party && i.partyId == partyId) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PartiesProvider>();
    final outgoing = context.watch<NotificationsProvider>().outgoing;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navParties),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: AppStrings.addParty,
            onPressed: () => _showPartySheet(context),
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
              hint: AppStrings.searchParties,
              onChanged: context.read<PartiesProvider>().updateSearch,
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.parties.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && provider.parties.isEmpty
                    ? AppErrorView(
                        onRetry: () => context
                            .read<PartiesProvider>()
                            .loadParties(refresh: true),
                      )
                    : provider.parties.isEmpty
                        ? EmptyState.line(
                            kind: LineArt.customers,
                            title: AppStrings.noParties,
                            subtitle: AppStrings.noPartiesHint,
                            action: AppButton.primary(
                              label: AppStrings.addParty,
                              icon: Icons.add_rounded,
                              onPressed: () => _showPartySheet(context),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => context
                                .read<PartiesProvider>()
                                .loadParties(refresh: true),
                            color: AppColors.black,
                            backgroundColor: AppColors.white,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.sm,
                              ),
                              itemCount: provider.parties.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (context, i) {
                                final p = provider.parties[i];
                                return _PartyTile(
                                  party: p,
                                  invite: _inviteFor(p.id, outgoing),
                                  onTap: () => _openDetail(context, p),
                                  onEdit: () =>
                                      _showPartySheet(context, party: p),
                                  onDelete: () => _confirmDelete(context, p),
                                  onInvite: () => _openInvite(context, p),
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

  Future<void> _openDetail(BuildContext context, Party p) async {
    // Capture before await so the post-pop refresh doesn't reach back
    // into a possibly-disposed BuildContext.
    final provider = context.read<PartiesProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PartyDetailPage(partyId: p.id)),
    );
    if (mounted) provider.loadParties(refresh: true);
  }

  void _showPartySheet(BuildContext context, {Party? party}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      builder: (_) => PartyFormSheet(party: party),
    );
  }

  Future<void> _openInvite(BuildContext context, Party p) async {
    final notifs = context.read<NotificationsProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SendInvitePage(initialParty: p),
      ),
    );
    // Refresh status chips after the send sheet closes. Provider grabbed
    // before the await so we don't touch a possibly-disposed context.
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

  Future<void> _confirmDelete(BuildContext context, Party party) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppStrings.deleteParty,
      message: '${AppStrings.deletePartyConfirm} "${party.name}"?',
      confirmLabel: AppStrings.delete,
      danger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<PartiesProvider>().deleteParty(party.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.partyDeleted)),
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

class _PartyTile extends StatelessWidget {
  const _PartyTile({
    required this.party,
    required this.invite,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onInvite,
    required this.onCancelInvite,
  });
  final Party party;
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
              AppMonogramAvatar(label: party.name),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (party.phone != null)
                      Text(
                        party.phone!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    if (party.gstin != null)
                      Text(
                        'GSTIN: ${party.gstin}',
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
                          label: '${party.challanCount} challans',
                          icon: Icons.description_outlined,
                          dense: true,
                        ),
                        AppStatusBadge(
                          label: '${party.invoiceCount} invoices',
                          icon: Icons.receipt_outlined,
                          dense: true,
                        ),
                        if (party.cautionBalance > 0)
                          AppStatusBadge(
                            label:
                                'Caution ${AppStrings.currencySymbol}${party.cautionBalance.toStringAsFixed(0)}',
                            icon: Icons.savings_outlined,
                            tone: AppStatusTone.info,
                            weight: AppStatusWeight.soft,
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

  bool get _canInvite => (party.email ?? '').isNotEmpty;

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
            // Linked customers don't get a re-invite affordance — the
            // chip on the tile already signals "Linked" and showing the
            // button would imply a re-send is possible when it's not.
            if (invite?.isAccepted == true)
              ListTile(
                leading: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.success,
                ),
                title: const Text(
                  'Already linked',
                  style: TextStyle(color: AppColors.success),
                ),
                subtitle: Text(
                  invite!.toEmail,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                enabled: false,
              )
            else if (invite == null || !invite!.isPending) ...[
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
                    ? Text(party.email!,
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
                leading: const Icon(
                  Icons.cancel_schedule_send_outlined,
                  color: AppColors.warning,
                ),
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

/// Status pill reflecting the most recent invitation sent for this
/// party. Hidden when there's no invite so calm cases stay calm.
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

class PartyFormSheet extends StatefulWidget {
  const PartyFormSheet({super.key, this.party});
  final Party? party;

  @override
  State<PartyFormSheet> createState() => _PartyFormSheetState();
}

class _PartyFormSheetState extends State<PartyFormSheet> {
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

  bool get isEditing => widget.party != null;

  @override
  void initState() {
    super.initState();
    final p = widget.party;
    _name = TextEditingController(text: p?.name ?? '');
    _contactName = TextEditingController(text: p?.contactName ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    _email = TextEditingController(text: p?.email ?? '');
    _address = TextEditingController(text: p?.address ?? '');
    _city = TextEditingController(text: p?.city ?? '');
    _pinCode = TextEditingController(text: p?.pinCode ?? '');
    _panNumber = TextEditingController(text: p?.panNumber ?? '');
    _gstin = TextEditingController(text: p?.gstin ?? '');
    _stateCode = p?.stateCode;
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
      final provider = context.read<PartiesProvider>();
      // Resolve state name from picked code so the backend gets both
      // halves of the GST state pair consistently.
      final stateName = IndianStates.stateNameFromCode(_stateCode);
      Party saved;
      if (isEditing) {
        saved = await provider.updateParty(
          widget.party!.id,
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
        saved = await provider.createParty(
          name: _name.text,
          contactName:
              _contactName.text.isNotEmpty ? _contactName.text : null,
          phone: _phone.text.isNotEmpty ? _phone.text : null,
          email: _email.text.isNotEmpty ? _email.text : null,
          address: _address.text.isNotEmpty ? _address.text : null,
          city: _city.text.isNotEmpty ? _city.text : null,
          state: stateName,
          stateCode: _stateCode,
          pinCode: _pinCode.text.isNotEmpty ? _pinCode.text : null,
          panNumber:
              _panNumber.text.isNotEmpty ? _panNumber.text.toUpperCase() : null,
          gstin: _gstin.text.isNotEmpty ? _gstin.text.toUpperCase() : null,
        );
      }
      if (mounted) Navigator.pop(context, saved);
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
                  kind: LineArt.customers,
                  size: 88,
                  accent: AppColors.brand,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                isEditing ? AppStrings.editParty : AppStrings.addParty,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.lg),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: AppStrings.partyName,
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _gstin,
                      decoration: const InputDecoration(
                        labelText: AppStrings.gstin,
                      ),
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
                decoration: const InputDecoration(
                  labelText: AppStrings.address,
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _city,
                      decoration: const InputDecoration(labelText: 'City'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextFormField(
                      controller: _pinCode,
                      decoration: const InputDecoration(labelText: 'PIN code'),
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
                decoration: const InputDecoration(labelText: 'State'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('— Select —'),
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
