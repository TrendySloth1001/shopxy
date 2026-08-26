import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

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

class _Recipient {
  const _Recipient.party(this.party) : vendor = null, newName = null;
  const _Recipient.vendor(this.vendor) : party = null, newName = null;
  const _Recipient.fresh(this.newName) : party = null, vendor = null;

  final Party? party;
  final Vendor? vendor;
  final String? newName;

  bool get isNew => newName != null;
  String get label => party?.name ?? vendor?.name ?? newName ?? '';
  String? get email => party?.email ?? vendor?.email;
}

class _SendInvitePageState extends State<SendInvitePage> {
  _LinkType? _type;
  _Recipient? _recipient;

  final _emailCtl = TextEditingController();
  final _messageCtl = TextEditingController();

  bool _sending = false;
  String? _error;

  bool get _lockedToType =>
      widget.initialParty != null || widget.initialVendor != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialVendor != null) {
      _type = _LinkType.vendor;
      _recipient = _Recipient.vendor(widget.initialVendor);
      _emailCtl.text = widget.initialVendor!.email ?? '';
    } else if (widget.initialParty != null) {
      _type = _LinkType.party;
      _recipient = _Recipient.party(widget.initialParty);
      _emailCtl.text = widget.initialParty!.email ?? '';
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _messageCtl.dispose();
    super.dispose();
  }

  bool get _emailOk => _emailCtl.text.trim().contains('@');
  bool get _canSend => _recipient != null && _emailOk && !_sending;

  String? _blockingHint(AppLocalizations l10n) {
    if (_recipient == null) return l10n.inviteHintPickContact;
    if (!_emailOk) return l10n.inviteHintNeedEmail;
    return null;
  }

  String _roleWord(AppLocalizations l10n) => _type == _LinkType.party
      ? l10n.inviteWordCustomer
      : l10n.inviteWordSupplier;

  void _pickType(_LinkType t) => setState(() {
    _type = t;
    _recipient = null;
    _emailCtl.clear();
  });

  void _pickRecipient(_Recipient r) => setState(() {
    _recipient = r;
    final known = r.email;
    if (known != null && known.isNotEmpty) _emailCtl.text = known;
  });

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final r = _recipient!;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await context.read<NotificationsProvider>().sendInvite(
        toEmail: _emailCtl.text.trim(),
        linkType: _type == _LinkType.party ? 'PARTY' : 'VENDOR',
        partyId: r.party?.id,
        vendorId: r.vendor?.id,
        displayName: r.isNew ? r.newName : null,
        message: _messageCtl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.notificationsInvitationSent)));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = _blockingHint(l10n);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.notificationsSendInvitationTitle),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.sm + FloatingAppBar.contentTopInset(context),
                AppSizes.lg,
                AppSizes.xl,
              ),
              children: [
                if (_type == null)
                  _RoleChooser(onPick: _pickType)
                else if (!_lockedToType)
                  _ChosenRoleRow(
                    type: _type!,
                    onChange: () => setState(() {
                      _type = null;
                      _recipient = null;
                      _emailCtl.clear();
                    }),
                  ),

                if (_type != null) ...[
                  const SizedBox(height: AppSizes.xl),
                  if (_recipient == null)
                    _ContactStep(
                      key: ValueKey('contact-${_type!.name}'),
                      type: _type!,
                      roleWord: _roleWord(l10n),
                      onPicked: _pickRecipient,
                    )
                  else
                    _ChosenContactRow(
                      recipient: _recipient!,
                      roleWord: _roleWord(l10n),
                      onChange: _lockedToType
                          ? null
                          : () => setState(() {
                              _recipient = null;
                              _emailCtl.clear();
                            }),
                    ),
                ],

                if (_recipient != null) ...[
                  const SizedBox(height: AppSizes.xl),
                  _StepHeader(
                    step: 3,
                    title: l10n.inviteEmailTitle,
                    subtitle: l10n.inviteEmailHelp,
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextField(
                    controller: _emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofocus: _emailCtl.text.isEmpty,
                    decoration: InputDecoration(
                      labelText: l10n.notificationsRecipientEmail,
                      prefixIcon: const AppIcon(AppIcons.alternateEmailRounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextField(
                    controller: _messageCtl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: l10n.notificationsMessageOptional,
                      hintText: l10n.notificationsMessageHint,
                    ),
                  ),
                ],

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
                        AppIcon(
                          AppIcons.errorOutlineRounded,
                          color: AppColors.error,
                          size: AppSizes.iconMd,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
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
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.md + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hint != null) ...[
                  Row(
                    children: [
                      AppIcon(
                        AppIcons.infoOutlineRounded,
                        size: AppSizes.iconSm,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: AppSizes.xs),
                      Expanded(
                        child: Text(
                          hint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                ],
                AppButton.primary(
                  label: l10n.notificationsSendInvitationTitle,
                  icon: AppIcons.sendRounded,
                  isLoading: _sending,
                  fullWidth: true,
                  onPressed: _canSend ? _send : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChooser extends StatelessWidget {
  const _RoleChooser({required this.onPick});
  final ValueChanged<_LinkType> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(step: 1, title: l10n.inviteWhoTitle),
        const SizedBox(height: AppSizes.md),
        _RoleCard(
          icon: AppIcons.groupsOutlined,
          accent: AppColors.accentRose,
          accentSoft: AppColors.accentRoseSoft,
          title: l10n.inviteRoleCustomer,
          body: l10n.inviteRoleCustomerDesc,
          onTap: () => onPick(_LinkType.party),
        ),
        const SizedBox(height: AppSizes.sm),
        _RoleCard(
          icon: AppIcons.storefrontOutlined,
          accent: AppColors.accentIndigo,
          accentSoft: AppColors.accentIndigoSoft,
          title: l10n.inviteRoleSupplier,
          body: l10n.inviteRoleSupplierDesc,
          onTap: () => onPick(_LinkType.vendor),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final AppIconData icon;
  final Color accent;
  final Color accentSoft;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Row(
            children: [
              Container(
                width: AppSizes.xxxl,
                height: AppSizes.xxxl,
                decoration: ShapeDecoration(
                  color: accentSoft,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: AppIcon(icon, color: accent, size: AppSizes.iconMd),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.bold),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              AppIcon(
                AppIcons.chevronRightRounded,
                size: AppSizes.iconSm,
                color: AppColors.subtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChosenRoleRow extends StatelessWidget {
  const _ChosenRoleRow({required this.type, required this.onChange});
  final _LinkType type;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isParty = type == _LinkType.party;
    return _SummaryRow(
      icon: isParty ? AppIcons.groupsOutlined : AppIcons.storefrontOutlined,
      accent: isParty ? AppColors.accentRose : AppColors.accentIndigo,
      accentSoft: isParty
          ? AppColors.accentRoseSoft
          : AppColors.accentIndigoSoft,
      title: isParty ? l10n.inviteRoleCustomer : l10n.inviteRoleSupplier,
      onChange: onChange,
    );
  }
}

class _ContactStep extends StatefulWidget {
  const _ContactStep({
    super.key,
    required this.type,
    required this.roleWord,
    required this.onPicked,
  });

  final _LinkType type;
  final String roleWord;
  final ValueChanged<_Recipient> onPicked;

  @override
  State<_ContactStep> createState() => _ContactStepState();
}

class _ContactStepState extends State<_ContactStep> {
  final _searchCtl = TextEditingController();
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _load() {
    final q = _searchCtl.text.trim();
    if (widget.type == _LinkType.party) {
      return context.read<PartiesRemoteDataSource>().getParties(
        search: q.isEmpty ? null : q,
      );
    }
    return context.read<VendorsRemoteDataSource>().getVendors(
      search: q.isEmpty ? null : q,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = _searchCtl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(step: 2, title: l10n.inviteContactTitle),
        const SizedBox(height: AppSizes.md),
        TextField(
          controller: _searchCtl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l10n.inviteContactHint,
            prefixIcon: const AppIcon(AppIcons.searchRounded),
          ),
          onChanged: (_) => _reload(),
        ),
        const SizedBox(height: AppSizes.sm),
        FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _ContactListSkeleton();
            }
            final list = snap.hasError
                ? const <dynamic>[]
                : (snap.data ?? const <dynamic>[]);
            final exact = list.any(
              (e) =>
                  (e is Party ? e.name : (e as Vendor).name).toLowerCase() ==
                  query.toLowerCase(),
            );
            final showAddNew = query.isNotEmpty && !exact;

            if (list.isEmpty && !showAddNew) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                child: Text(
                  snap.hasError
                      ? friendlyError(snap.error!)
                      : l10n.notificationsNoContactsFound,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: snap.hasError ? AppColors.error : AppColors.muted,
                  ),
                ),
              );
            }

            return Container(
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: AppShapes.squircle(
                  AppSizes.radiusLg,
                  side: BorderSide(color: AppColors.hairline),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) Container(height: 1, color: AppColors.hairline),
                    _ContactRow(
                      item: list[i],
                      onTap: () => widget.onPicked(
                        list[i] is Party
                            ? _Recipient.party(list[i] as Party)
                            : _Recipient.vendor(list[i] as Vendor),
                      ),
                    ),
                  ],
                  if (showAddNew) ...[
                    if (list.isNotEmpty)
                      Container(height: 1, color: AppColors.hairline),
                    _AddNewRow(
                      label: l10n.inviteAddAsNew(query, widget.roleWord),
                      onTap: () => widget.onPicked(_Recipient.fresh(query)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.item, required this.onTap});
  final dynamic item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = item is Party ? item.name : (item as Vendor).name;
    final email = item is Party ? item.email : (item as Vendor).email;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name as String,
                    style: theme.textTheme.bodyMedium?.semibold,
                  ),
                  if (email != null && (email as String).isNotEmpty)
                    Text(
                      email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            AppIcon(
              AppIcons.chevronRightRounded,
              size: AppSizes.iconSm,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddNewRow extends StatelessWidget {
  const _AddNewRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            AppIcon(
              AppIcons.personAddAlt1Outlined,
              size: AppSizes.iconMd,
              color: AppColors.brand,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChosenContactRow extends StatelessWidget {
  const _ChosenContactRow({
    required this.recipient,
    required this.roleWord,
    required this.onChange,
  });

  final _Recipient recipient;
  final String roleWord;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SummaryRow(
      icon: AppIcons.personOutlineRounded,
      accent: AppColors.brandStrong,
      accentSoft: AppColors.brandSoft,
      title: recipient.label,
      badge: recipient.isNew ? l10n.inviteNewContactBadge(roleWord) : null,
      onChange: onChange,
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, this.subtitle});
  final int step;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AppSizes.xl,
              height: AppSizes.xl,
              decoration: ShapeDecoration(
                color: AppColors.brandSoft,
                shape: const CircleBorder(),
              ),
              alignment: Alignment.center,
              child: Text(
                '$step',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium?.bold)),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSizes.xs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.title,
    this.badge,
    required this.onChange,
  });

  final AppIconData icon;
  final Color accent;
  final Color accentSoft;
  final String title;
  final String? badge;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.sm,
        AppSizes.sm,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.xxl,
            height: AppSizes.xxl,
            decoration: ShapeDecoration(
              color: accentSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(icon, color: accent, size: AppSizes.iconSm),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.semibold,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: AppSizes.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xxs,
              ),
              decoration: ShapeDecoration(
                color: AppColors.brandSoft,
                shape: AppShapes.squircle(AppSizes.radiusFull),
              ),
              child: Text(
                badge!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (onChange != null)
            TextButton(onPressed: onChange, child: Text(l10n.inviteChange)),
        ],
      ),
    );
  }
}

class _ContactListSkeleton extends StatelessWidget {
  const _ContactListSkeleton();

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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) Container(height: 1, color: AppColors.hairline),
            const _ContactRowSkeleton(),
          ],
        ],
      ),
    );
  }
}

class _ContactRowSkeleton extends StatelessWidget {
  const _ContactRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerLine(widthFactor: 0.5, height: 14),
          const SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.35, height: 11),
        ],
      ),
    );
  }
}
