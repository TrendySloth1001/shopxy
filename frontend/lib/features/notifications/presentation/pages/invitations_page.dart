import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/notifications/presentation/pages/send_invite_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/notifications/presentation/widgets/empty_hint.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Invitations — the merchant's connection-management surface, reached
/// from Menu → Manage.
///
/// This deliberately does NOT live under Notifications. Notifications is
/// a feed of things that happened; deciding who is linked to your shop is
/// active management, and it belongs next to Team / Parties / Vendors.
/// (An arriving invite still shows up in the notifications feed as an
/// actionable card — that part genuinely is an event — and tapping it
/// lands here.)
class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key, this.initialTab = 0});

  /// 0 = Received, 1 = Sent. The notifications feed deep-links to the
  /// matching tab so an INVITE_RECEIVED card opens on Received and an
  /// INVITE_ACCEPTED/EXPIRED card (about something you sent) opens Sent.
  final int initialTab;

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _incomingScrollCtrl = ScrollController();
  final _outgoingScrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _incomingHaptics;
  late final ScrollBoundaryHaptics _outgoingHaptics;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _incomingHaptics = ScrollBoundaryHaptics(_incomingScrollCtrl);
    _outgoingHaptics = ScrollBoundaryHaptics(_outgoingScrollCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<NotificationsProvider>();
      p.loadIncoming();
      p.loadOutgoing();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _incomingHaptics.dispose();
    _incomingScrollCtrl.dispose();
    _outgoingHaptics.dispose();
    _outgoingScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pendingInvites = context.select<NotificationsProvider, int>(
      (p) => p.pendingIncoming.length,
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.invitationsTitle,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              text: pendingInvites > 0
                  ? '${l10n.invitationsTabReceived} ($pendingInvites)'
                  : l10n.invitationsTabReceived,
            ),
            Tab(text: l10n.notificationsTabSent),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SendInvitePage()),
        ),
        icon: const AppIcon(AppIcons.personAddAlt1Rounded),
        label: Text(l10n.notificationsInviteButton),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _IncomingTab(controller: _incomingScrollCtrl),
          _OutgoingTab(controller: _outgoingScrollCtrl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Received
// ─────────────────────────────────────────────────────────────────────

class _IncomingTab extends StatelessWidget {
  const _IncomingTab({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Scoped to just `incoming` — an inbox/outgoing mutation elsewhere
    // doesn't repaint this tab.
    final incoming = context.select<NotificationsProvider, List<Invitation>>(
      (p) => p.incoming,
    );
    if (incoming.isEmpty) {
      return EmptyHint(
        icon: AppIcons.markEmailUnreadOutlined,
        title: l10n.notificationsIncomingEmptyTitle,
        body: l10n.notificationsIncomingEmptyBody,
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<NotificationsProvider>().loadIncoming(),
      color: AppColors.brand,
      child: ListView.separated(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm +
              FloatingAppBar.contentTopInset(context) +
              kTextTabBarHeight,
          AppSizes.lg,
          AppSizes.massive + AppSizes.xxxl,
        ),
        itemCount: incoming.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
        itemBuilder: (_, i) => _IncomingInviteTile(invite: incoming[i]),
      ),
    );
  }
}

class _IncomingInviteTile extends StatelessWidget {
  const _IncomingInviteTile({required this.invite});
  final Invitation invite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final p = context.read<NotificationsProvider>();
    final shopName =
        invite.fromShopName ?? invite.fromUserName ?? l10n.notificationsAShop;
    final roleLabel = invite.isParty
        ? l10n.notificationsRolePartyCustomer
        : l10n.notificationsRoleVendorSupplier;

    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.xxxl,
                height: AppSizes.xxxl,
                decoration: ShapeDecoration(
                  color: invite.isParty
                      ? AppColors.accentRoseSoft
                      : AppColors.accentIndigoSoft,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  invite.isParty
                      ? AppIcons.groupsOutlined
                      : AppIcons.storefrontOutlined,
                  color: invite.isParty
                      ? AppColors.accentRose
                      : AppColors.accentIndigo,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${l10n.notificationsWantsToAddYou(roleLabel)}'
                      '${invite.displayName != null ? " — \"${invite.displayName}\"" : ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: invite.effectiveStatus),
            ],
          ),
          if (invite.message != null) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              child: Text(
                invite.message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.black,
                ),
              ),
            ),
          ],
          if (invite.isPending) ...[
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _decline(context, p),
                    icon: const AppIcon(
                      AppIcons.closeRounded,
                      size: AppSizes.iconMd,
                    ),
                    label: Text(l10n.notificationsDecline),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _accept(context, p),
                    icon: const AppIcon(
                      AppIcons.checkRounded,
                      size: AppSizes.iconMd,
                    ),
                    label: Text(l10n.notificationsAccept),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _accept(BuildContext context, NotificationsProvider p) async {
    final l10n = AppLocalizations.of(context);
    try {
      await p.accept(invite.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsInvitationAccepted)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _decline(BuildContext context, NotificationsProvider p) async {
    final l10n = AppLocalizations.of(context);
    try {
      await p.decline(invite.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notificationsInvitationDeclined)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Outgoing invitations
// ─────────────────────────────────────────────────────────────────────

class _OutgoingTab extends StatelessWidget {
  const _OutgoingTab({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Scoped to just `outgoing` — an inbox/incoming mutation elsewhere
    // doesn't repaint this tab.
    final outgoing = context.select<NotificationsProvider, List<Invitation>>(
      (p) => p.outgoing,
    );
    if (outgoing.isEmpty) {
      return EmptyHint(
        icon: AppIcons.outboxOutlined,
        title: l10n.notificationsOutgoingEmptyTitle,
        body: l10n.notificationsOutgoingEmptyBody,
        // An empty list shouldn't be a dead end — give the one action
        // this screen exists for rather than making them hunt for the FAB.
        action: AppButton.primary(
          label: l10n.notificationsSendInvitationTitle,
          icon: AppIcons.personAddAlt1Rounded,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SendInvitePage()),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<NotificationsProvider>().loadOutgoing(),
      color: AppColors.brand,
      child: ListView.separated(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm +
              FloatingAppBar.contentTopInset(context) +
              kTextTabBarHeight,
          AppSizes.lg,
          AppSizes.massive + AppSizes.xxxl,
        ),
        itemCount: outgoing.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
        itemBuilder: (_, i) {
          final invite = outgoing[i];
          return _OutgoingInviteTile(invite: invite);
        },
      ),
    );
  }
}

class _OutgoingInviteTile extends StatelessWidget {
  const _OutgoingInviteTile({required this.invite});
  final Invitation invite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Same rounded-surface-card recipe as the inbox tiles. The row itself
    // is now the tap target — it opens a details sheet with the cancel
    // action inside, rather than a bare unlabelled "x" sitting next to the
    // status chip (that read as an ambiguous dismiss, not a destructive
    // cancel-this-invite action).
    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        onTap: () => _OutgoingInviteDetailsSheet.show(context, invite),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.xxxl,
                height: AppSizes.xxxl,
                decoration: ShapeDecoration(
                  color: invite.isParty
                      ? AppColors.accentRoseSoft
                      : AppColors.accentIndigoSoft,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  invite.isParty
                      ? AppIcons.groupsOutlined
                      : AppIcons.storefrontOutlined,
                  color: invite.isParty
                      ? AppColors.accentRose
                      : AppColors.accentIndigo,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.toEmail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      invite.displayName ??
                          (invite.isParty
                              ? l10n.notificationsRoleParty
                              : l10n.notificationsRoleVendor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              _StatusChip(status: invite.effectiveStatus),
              const SizedBox(width: AppSizes.xs),
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

/// Details sheet for a sent invitation — opened by tapping the row in the
/// Sent tab. Shows what was sent and to whom, with the destructive cancel
/// action living here (behind a deliberate tap + sheet open) instead of a
/// bare icon inline on the row.
class _OutgoingInviteDetailsSheet extends StatefulWidget {
  const _OutgoingInviteDetailsSheet({required this.invite});
  final Invitation invite;

  static Future<void> show(BuildContext context, Invitation invite) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => _OutgoingInviteDetailsSheet(invite: invite),
    );
  }

  @override
  State<_OutgoingInviteDetailsSheet> createState() =>
      _OutgoingInviteDetailsSheetState();
}

class _OutgoingInviteDetailsSheetState
    extends State<_OutgoingInviteDetailsSheet> {
  static final _dateFmt = DateFormat('d MMM y · hh:mm a');
  bool _cancelling = false;

  Invitation get invite => widget.invite;

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    setState(() => _cancelling = true);
    try {
      await context.read<NotificationsProvider>().cancel(invite.id);
      if (!mounted) return;
      navigator.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.notificationsInvitationCancelled)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.lg + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: AppSizes.xxxl,
              height: AppSizes.xxs,
              margin: const EdgeInsets.only(bottom: AppSizes.lg),
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: AppSizes.xxxl,
                height: AppSizes.xxxl,
                decoration: ShapeDecoration(
                  color: invite.isParty
                      ? AppColors.accentRoseSoft
                      : AppColors.accentIndigoSoft,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  invite.isParty
                      ? AppIcons.groupsOutlined
                      : AppIcons.storefrontOutlined,
                  color: invite.isParty
                      ? AppColors.accentRose
                      : AppColors.accentIndigo,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.notificationsInviteDetailsTitle,
                      style: theme.textTheme.titleMedium?.bold,
                    ),
                    Text(
                      invite.toEmail,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: invite.effectiveStatus),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          _DetailRow(
            label: l10n.notificationsDetailRole,
            value: invite.displayName ??
                (invite.isParty
                    ? l10n.notificationsRoleParty
                    : l10n.notificationsRoleVendor),
          ),
          _DetailRow(
            label: l10n.notificationsDetailSentOn,
            value: _dateFmt.format(invite.createdAt.toLocal()),
          ),
          _DetailRow(
            label: l10n.notificationsDetailExpires,
            value: _dateFmt.format(invite.expiresAt.toLocal()),
          ),
          if (invite.message != null && invite.message!.isNotEmpty)
            _DetailRow(
              label: l10n.notificationsDetailMessage,
              value: invite.message!,
            ),
          if (invite.isPending) ...[
            const SizedBox(height: AppSizes.lg),
            AppButton.danger(
              label: l10n.notificationsCancelInvitation,
              icon: AppIcons.closeRounded,
              isLoading: _cancelling,
              fullWidth: true,
              onPressed: _cancel,
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSizes.massive,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Bits
// ─────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final InviteStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, fg, bg) = switch (status) {
      InviteStatus.pending => (
        l10n.notificationsStatusPending,
        AppColors.warning,
        AppColors.warningSoft,
      ),
      InviteStatus.accepted => (
        l10n.notificationsStatusAccepted,
        AppColors.success,
        AppColors.successSoft,
      ),
      InviteStatus.declined => (
        l10n.notificationsStatusDeclined,
        AppColors.muted,
        AppColors.heroPanel,
      ),
      InviteStatus.cancelled => (
        l10n.notificationsStatusCancelled,
        AppColors.muted,
        AppColors.heroPanel,
      ),
      InviteStatus.expired => (
        l10n.notificationsStatusExpired,
        AppColors.error,
        AppColors.errorSoft,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

