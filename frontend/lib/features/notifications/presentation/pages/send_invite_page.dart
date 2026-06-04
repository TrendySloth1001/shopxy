import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Owner-facing page. Two modes via a segmented switch:
///   * **Existing contact** — search-pick a party / vendor; the FK
///     goes onto the invitation.
///   * **New contact** — type a name + email; no FK. The backend
///     materialises the Party/Vendor row when the invitee accepts.
///
/// When opened from a party or vendor row, pass [initialParty] or
/// [initialVendor] to pre-fill the picker + email field. The type
/// switch is locked in that case so the user can't accidentally flip
/// to the wrong side and lose the selection.
class SendInvitePage extends StatefulWidget {
  const SendInvitePage({super.key, this.initialParty, this.initialVendor})
      : assert(
          initialParty == null || initialVendor == null,
          'Pass only one of initialParty / initialVendor',
        );

  final Party? initialParty;
  final Vendor? initialVendor;

  @override
  State<SendInvitePage> createState() => _SendInvitePageState();
}

enum _LinkType { party, vendor }

enum _SourceMode { existing, fresh }

class _SendInvitePageState extends State<SendInvitePage> {
  late _LinkType _type;
  _SourceMode _mode = _SourceMode.existing;

  final _emailCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _messageCtl = TextEditingController();

  Party? _selectedParty;
  Vendor? _selectedVendor;

  bool _sending = false;
  String? _error;

  bool get _lockedToType =>
      widget.initialParty != null || widget.initialVendor != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialVendor != null) {
      _type = _LinkType.vendor;
      _selectedVendor = widget.initialVendor;
      _emailCtl.text = widget.initialVendor!.email ?? '';
    } else if (widget.initialParty != null) {
      _type = _LinkType.party;
      _selectedParty = widget.initialParty;
      _emailCtl.text = widget.initialParty!.email ?? '';
    } else {
      _type = _LinkType.party;
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _nameCtl.dispose();
    _messageCtl.dispose();
    super.dispose();
  }

  bool get _canSend {
    final emailOk = _emailCtl.text.trim().contains('@');
    final selOk = _mode == _SourceMode.fresh
        ? _nameCtl.text.trim().isNotEmpty
        : _type == _LinkType.party
            ? _selectedParty != null
            : _selectedVendor != null;
    return emailOk && selOk && !_sending;
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<NotificationsProvider>().sendInvite(
            toEmail: _emailCtl.text.trim(),
            linkType: _type == _LinkType.party ? 'PARTY' : 'VENDOR',
            partyId: _mode == _SourceMode.existing && _type == _LinkType.party
                ? _selectedParty?.id
                : null,
            vendorId: _mode == _SourceMode.existing && _type == _LinkType.vendor
                ? _selectedVendor?.id
                : null,
            displayName: _mode == _SourceMode.fresh ? _nameCtl.text.trim() : null,
            message: _messageCtl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Send invitation')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
                  Text(
                    'Invite by email',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    'They will see your request under Notifications. '
                    "If they don't have a Shopxy account yet, it shows "
                    'up the moment they sign up with this email.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),
                  _TypeSwitch(
                    value: _type,
                    locked: _lockedToType,
                    onChanged: (v) => setState(() {
                      _type = v;
                      _selectedParty = null;
                      _selectedVendor = null;
                    }),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  _ModeSwitch(
                    value: _mode,
                    onChanged: (v) => setState(() {
                      _mode = v;
                      _selectedParty = null;
                      _selectedVendor = null;
                      _nameCtl.clear();
                    }),
                  ),
                  const SizedBox(height: AppSizes.xl),
                  if (_mode == _SourceMode.existing)
                    _ContactPicker(
                      key: ValueKey('picker-${_type.name}'),
                      type: _type,
                      selectedParty: _selectedParty,
                      selectedVendor: _selectedVendor,
                      onPartyPicked: (p) => setState(() {
                        _selectedParty = p;
                        if ((p.email ?? '').isNotEmpty) _emailCtl.text = p.email!;
                      }),
                      onVendorPicked: (v) => setState(() {
                        _selectedVendor = v;
                        if ((v.email ?? '').isNotEmpty) _emailCtl.text = v.email!;
                      }),
                    )
                  else
                    TextField(
                      controller: _nameCtl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: _type == _LinkType.party
                            ? 'Customer name'
                            : 'Vendor name',
                        prefixIcon: Icon(
                          _type == _LinkType.party
                              ? Icons.groups_outlined
                              : Icons.storefront_outlined,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  const SizedBox(height: AppSizes.xl),
                  TextField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Recipient email',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextField(
                    controller: _messageCtl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Message (optional)',
                      hintText: 'Hey! Linking your account on Shopxy…',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: ShapeDecoration(
                        color: AppColors.errorSoft,
                        shape: AppShapes.squircle(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: AppSizes.iconMd),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.hairline)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                AppSizes.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSend ? _send : null,
                  icon: _sending
                      ? const SizedBox(
                          width: AppSizes.iconSm,
                          height: AppSizes.iconSm,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: AppSizes.iconMd),
                  label: const Text('Send invitation'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({
    required this.value,
    required this.onChanged,
    this.locked = false,
  });
  final _LinkType value;
  final ValueChanged<_LinkType> onChanged;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_LinkType>(
      segments: const [
        ButtonSegment(
          value: _LinkType.party,
          icon: Icon(Icons.groups_outlined),
          label: Text('Party (customer)'),
        ),
        ButtonSegment(
          value: _LinkType.vendor,
          icon: Icon(Icons.storefront_outlined),
          label: Text('Vendor (supplier)'),
        ),
      ],
      selected: {value},
      onSelectionChanged: locked ? null : (s) => onChanged(s.first),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.value, required this.onChanged});
  final _SourceMode value;
  final ValueChanged<_SourceMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_SourceMode>(
      segments: const [
        ButtonSegment(
          value: _SourceMode.existing,
          icon: Icon(Icons.contacts_outlined),
          label: Text('Existing'),
        ),
        ButtonSegment(
          value: _SourceMode.fresh,
          icon: Icon(Icons.person_add_alt_1_outlined),
          label: Text('New contact'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Contact picker (existing-contact mode)
// ─────────────────────────────────────────────────────────────────────

class _ContactPicker extends StatefulWidget {
  const _ContactPicker({
    super.key,
    required this.type,
    required this.selectedParty,
    required this.selectedVendor,
    required this.onPartyPicked,
    required this.onVendorPicked,
  });

  final _LinkType type;
  final Party? selectedParty;
  final Vendor? selectedVendor;
  final ValueChanged<Party> onPartyPicked;
  final ValueChanged<Vendor> onVendorPicked;

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  late Future<List<dynamic>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<dynamic>> _load() async {
    if (widget.type == _LinkType.party) {
      final ds = context.read<PartiesRemoteDataSource>();
      return ds.getParties(search: _search.isEmpty ? null : _search);
    }
    final ds = context.read<VendorsRemoteDataSource>();
    return ds.getVendors(search: _search.isEmpty ? null : _search);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.type == _LinkType.party ? 'Choose party' : 'Choose vendor',
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        TextField(
          decoration: InputDecoration(
            hintText: widget.type == _LinkType.party
                ? 'Search parties…'
                : 'Search vendors…',
            prefixIcon: const Icon(Icons.search_rounded),
          ),
          onChanged: (v) {
            _search = v;
            _reload();
          },
        ),
        const SizedBox(height: AppSizes.sm),
        SizedBox(
          height: 220,
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Text(
                    snap.error.toString(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                );
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return const Center(child: Text('No contacts found'));
              }
              return Container(
                decoration: ShapeDecoration(
                  color: AppColors.white,
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) =>
                      Container(height: 1, color: AppColors.hairline),
                  itemBuilder: (_, i) {
                    final item = list[i];
                    final name = item is Party ? item.name : (item as Vendor).name;
                    final email = item is Party ? item.email : (item as Vendor).email;
                    final selected = item is Party
                        ? widget.selectedParty?.id == item.id
                        : widget.selectedVendor?.id == (item as Vendor).id;
                    return InkWell(
                      onTap: () {
                        if (item is Party) {
                          widget.onPartyPicked(item);
                        } else if (item is Vendor) {
                          widget.onVendorPicked(item);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.lg,
                          vertical: AppSizes.md,
                        ),
                        color: selected ? AppColors.brandSoft : null,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (email != null && email.isNotEmpty)
                                    Text(
                                      email,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.brand,
                                size: AppSizes.iconMd,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
