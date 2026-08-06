import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/notifications/domain/entities/notification.dart';
import 'package:shopxy/features/notifications/presentation/pages/send_invite_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotation_detail_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotations_page.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _inboxScrollCtrl = ScrollController();
  final _incomingScrollCtrl = ScrollController();
  final _outgoingScrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _inboxHaptics;
  late final ScrollBoundaryHaptics _incomingHaptics;
  late final ScrollBoundaryHaptics _outgoingHaptics;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _inboxHaptics = ScrollBoundaryHaptics(_inboxScrollCtrl);
    _incomingHaptics = ScrollBoundaryHaptics(_incomingScrollCtrl);
    _outgoingHaptics = ScrollBoundaryHaptics(_outgoingScrollCtrl);
    _inboxScrollCtrl.addListener(_maybeLoadMoreInbox);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<NotificationsProvider>();
      p.loadInbox();
      p.loadIncoming();
      p.loadOutgoing();
    });
  }

  /// Fetches the next inbox page once the user scrolls within one screen
  /// of the bottom — avoids the merchant hitting a hard wall at 50 items
  /// with no way to see older notifications.
  void _maybeLoadMoreInbox() {
    if (!_inboxScrollCtrl.hasClients) return;
    final position = _inboxScrollCtrl.position;
    if (position.pixels < position.maxScrollExtent - position.viewportDimension) {
      return;
    }
    context.read<NotificationsProvider>().loadMoreInbox();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _inboxHaptics.dispose();
    _inboxScrollCtrl.removeListener(_maybeLoadMoreInbox);
    _inboxScrollCtrl.dispose();
    _incomingHaptics.dispose();
    _incomingScrollCtrl.dispose();
    _outgoingHaptics.dispose();
    _outgoingScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Scoped selects — the app bar only cares about the two badge counts,
    // so an incoming/outgoing-only mutation elsewhere doesn't repaint it.
    final unread = context.select<NotificationsProvider, int>((p) => p.unread);
    final pendingInvites = context.select<NotificationsProvider, int>(
      (p) => p.pendingIncoming.length,
    );
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.notificationsTitle,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              text: unread > 0
                  ? '${l10n.notificationsTabInbox} ($unread)'
                  : l10n.notificationsTabInbox,
            ),
            Tab(
              text: pendingInvites > 0
                  ? '${l10n.notificationsTabInvites} ($pendingInvites)'
                  : l10n.notificationsTabInvites,
            ),
            Tab(text: l10n.notificationsTabSent),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.notificationsMarkAllRead,
            icon: const AppIcon(AppIcons.doneAllRounded),
            onPressed: unread == 0
                ? null
                : context.read<NotificationsProvider>().markAllRead,
          ),
        ],
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
          _InboxTab(controller: _inboxScrollCtrl),
          _IncomingTab(controller: _incomingScrollCtrl),
          _OutgoingTab(controller: _outgoingScrollCtrl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Inbox
// ─────────────────────────────────────────────────────────────────────

typedef _InboxSlice = ({
  List<AppNotification> items,
  bool loading,
  bool loadingMore,
});

class _InboxTab extends StatelessWidget {
  const _InboxTab({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Scoped to just the inbox slice — an incoming/outgoing invite mutation
    // no longer repaints this tab (and vice versa for _IncomingTab/_OutgoingTab).
    final slice = context.select<NotificationsProvider, _InboxSlice>(
      (p) => (
        items: p.items,
        loading: p.isLoadingInbox,
        loadingMore: p.isLoadingMore,
      ),
    );
    if (slice.loading && slice.items.isEmpty) {
      return const _InboxSkeleton();
    }
    if (slice.items.isEmpty) {
      return _EmptyHint(
        icon: AppIcons.notificationsNoneRounded,
        title: l10n.notificationsInboxEmptyTitle,
        body: l10n.notificationsInboxEmptyBody,
      );
    }
    final itemCount = slice.items.length + (slice.loadingMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: () => context.read<NotificationsProvider>().loadInbox(),
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
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
        itemBuilder: (_, i) {
          if (i >= slice.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
              child: Center(
                child: SizedBox(
                  width: AppSizes.lg,
                  height: AppSizes.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final notification = slice.items[i];
          final newDay = i == 0 ||
              !_sameDay(
                notification.createdAt.toLocal(),
                slice.items[i - 1].createdAt.toLocal(),
              );
          final tile = _NotificationTile(notification: notification);
          if (!newDay) return tile;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_DateDivider(notification.createdAt.toLocal()), tile],
          );
        },
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Dated section break above the first notification of each day — a
/// centered "Today" / "Yesterday" / "12 Jul" pill flanked by hairlines.
class _DateDivider extends StatelessWidget {
  const _DateDivider(this.date);
  final DateTime date;

  static String _label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    if (that == today) return 'Today';
    if (today.difference(that).inDays == 1) return 'Yesterday';
    final fmt = now.year == date.year
        ? DateFormat('d MMM')
        : DateFormat('d MMM yyyy');
    return fmt.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          const Expanded(child: AppDivider.flush()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.xs,
              ),
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: AppShapes.squircle(
                  AppSizes.radiusFull,
                  side: BorderSide(color: AppColors.hairline),
                ),
              ),
              child: Text(
                _label(date),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Expanded(child: AppDivider.flush()),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.read<NotificationsProvider>();
    final accent = _accentFor(notification.kind);
    // Same rounded-surface-card recipe as _PartyTile/_InvoiceTile: a
    // Material + squircle border, never a flat full-bleed background wash.
    // Unread swaps to a brand-tinted fill + brand border (the same
    // "needs attention" treatment _TemplatesCallout uses), light in light
    // mode and a neutral dark puck in dark/OLED via AppColors.tileBg.
    return Material(
      color: notification.isUnread
          ? AppColors.tileBg(AppColors.brandSoft)
          : AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: BorderSide(
          color: notification.isUnread ? AppColors.brand : AppColors.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        onTap: () {
          if (notification.isUnread) p.markRead(notification.id);
          // Quotation notifications deep-link into the quotations feature;
          // other kinds remain informational (mark-read only) for now.
          if (notification.kind.startsWith('QUOTATION_')) {
            _openQuotation(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.xxxl,
              height: AppSizes.xxxl,
              decoration: ShapeDecoration(
                color: accent.$2,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                accent.$3,
                size: AppSizes.iconMd,
                color: accent.$1,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.black,
                      fontWeight: notification.isUnread
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (notification.body != null) ...[
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      notification.body!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    DateFormat(
                      'd MMM · hh:mm a',
                    ).format(notification.createdAt.toLocal()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.subtle,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.isUnread)
              Container(
                margin: const EdgeInsets.only(
                  left: AppSizes.sm,
                  top: AppSizes.sm,
                ),
                width: AppSizes.sm,
                height: AppSizes.sm,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Routes a QUOTATION_* notification to the quotation it references.
  ///
  /// There is no fetch-by-id endpoint, so we land on the quotations list
  /// immediately (fast feedback), reload the list, and — if the referenced
  /// quotation is found — push its detail page on top so "back" naturally
  /// returns to the list. Missing/unresolvable ids stop at the list.
  Future<void> _openQuotation(BuildContext context) async {
    final navigator = Navigator.of(context);
    final quotationsProvider = context.read<QuotationsProvider>();
    final raw = notification.data['quotationId'];
    final quotationId = raw?.toString();

    navigator.push(MaterialPageRoute(builder: (_) => const QuotationsPage()));
    if (quotationId == null) return;
    await quotationsProvider.load();
    for (final Quotation q in quotationsProvider.items) {
      if (q.id == quotationId) {
        navigator.push(
          MaterialPageRoute(builder: (_) => QuotationDetailPage(quotation: q)),
        );
        return;
      }
    }
  }

  (Color fg, Color bg, AppIconData icon) _accentFor(String kind) {
    switch (kind) {
      case 'INVITE_RECEIVED':
        return (
          AppColors.brandStrong,
          AppColors.brandSoft,
          AppIcons.mailOutlineRounded,
        );
      case 'INVITE_ACCEPTED':
        return (
          AppColors.success,
          AppColors.successSoft,
          AppIcons.checkCircleOutlineRounded,
        );
      case 'INVITE_DECLINED':
        return (
          AppColors.warning,
          AppColors.warningSoft,
          AppIcons.cancelOutlined,
        );
      case 'INVITE_CANCELLED':
        return (
          AppColors.muted,
          AppColors.heroPanel,
          AppIcons.cancelScheduleSendOutlined,
        );
      case 'INVITE_EXPIRED':
        return (
          AppColors.muted,
          AppColors.heroPanel,
          AppIcons.markEmailUnreadOutlined,
        );
      case 'QUOTATION_REQUESTED':
        return (
          AppColors.brandStrong,
          AppColors.brandSoft,
          AppIcons.requestQuoteOutlined,
        );
      case 'QUOTATION_ACCEPTED':
        return (
          AppColors.success,
          AppColors.successSoft,
          AppIcons.requestQuoteOutlined,
        );
      case 'QUOTATION_DECLINED':
        return (
          AppColors.warning,
          AppColors.warningSoft,
          AppIcons.requestQuoteOutlined,
        );
      case 'ORDER_RECEIVED':
      case 'ORDER_CONFIRMED':
      case 'ORDER_UPDATE':
        return (
          AppColors.info,
          AppColors.infoSoft,
          AppIcons.localShippingOutlined,
        );
      case 'ORDER_REJECTED':
        return (
          AppColors.warning,
          AppColors.warningSoft,
          AppIcons.localShippingOutlined,
        );
      case 'PAYMENT_RECEIVED':
        return (
          AppColors.success,
          AppColors.successSoft,
          AppIcons.paymentsOutlined,
        );
      case 'LOW_STOCK':
        return (
          AppColors.warning,
          AppColors.warningSoft,
          AppIcons.inventory2Outlined,
        );
      case 'RETURN_REQUESTED':
        return (
          AppColors.warning,
          AppColors.warningSoft,
          AppIcons.assignmentReturnOutlined,
        );
      case 'RETURN_APPROVED':
      case 'RETURN_REFUNDED':
        return (
          AppColors.success,
          AppColors.successSoft,
          AppIcons.assignmentReturnOutlined,
        );
      case 'RETURN_REJECTED':
        return (
          AppColors.error,
          AppColors.errorSoft,
          AppIcons.assignmentReturnOutlined,
        );
      case 'RETURN_UPDATE':
        return (
          AppColors.info,
          AppColors.infoSoft,
          AppIcons.assignmentReturnOutlined,
        );
      case 'SECURITY':
        return (
          AppColors.error,
          AppColors.errorSoft,
          AppIcons.shieldOutlined,
        );
      default:
        return (
          AppColors.accentIndigo,
          AppColors.accentIndigoSoft,
          AppIcons.notificationsNoneRounded,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Inbox skeleton
// ─────────────────────────────────────────────────────────────────────

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm +
            FloatingAppBar.contentTopInset(context) +
            kTextTabBarHeight,
        AppSizes.lg,
        AppSizes.massive + AppSizes.xxxl,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (_, _) => const _NotificationTileSkeleton(),
    );
  }
}

class _NotificationTileSkeleton extends StatelessWidget {
  const _NotificationTileSkeleton();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon squircle placeholder
          AppShimmerBox(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          // Text column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title line
                AppShimmerLine(widthFactor: 0.55, height: 14),
                const SizedBox(height: AppSizes.xs),
                // Optional body line
                AppShimmerLine(widthFactor: 0.80, height: 12),
                const SizedBox(height: AppSizes.xs),
                // Timestamp line
                AppShimmerLine(widthFactor: 0.35, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Incoming invitations
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
      return _EmptyHint(
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
      return _EmptyHint(
        icon: AppIcons.outboxOutlined,
        title: l10n.notificationsOutgoingEmptyTitle,
        body: l10n.notificationsOutgoingEmptyBody,
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.body,
  });
  final AppIconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: true,
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppSizes.massive,
                height: AppSizes.massive,
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusLg),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  icon,
                  color: AppColors.muted,
                  size: AppSizes.iconXl,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium?.bold,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
