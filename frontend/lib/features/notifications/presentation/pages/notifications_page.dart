import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<NotificationsProvider>();
      p.loadInbox();
      p.loadIncoming();
      p.loadOutgoing();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.watch<NotificationsProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.notificationsTitle,
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(
              text: p.unread > 0
                  ? '${l10n.notificationsTabInbox} (${p.unread})'
                  : l10n.notificationsTabInbox,
            ),
            Tab(
              text: p.pendingIncoming.isNotEmpty
                  ? '${l10n.notificationsTabInvites} (${p.pendingIncoming.length})'
                  : l10n.notificationsTabInvites,
            ),
            Tab(text: l10n.notificationsTabSent),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.notificationsMarkAllRead,
            icon: const AppIcon(AppIcons.doneAllRounded),
            onPressed: p.unread == 0 ? null : p.markAllRead,
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
        children: const [_InboxTab(), _IncomingTab(), _OutgoingTab()],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Inbox
// ─────────────────────────────────────────────────────────────────────

class _InboxTab extends StatelessWidget {
  const _InboxTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.watch<NotificationsProvider>();
    if (p.isLoadingInbox && p.items.isEmpty) {
      return const _InboxSkeleton();
    }
    if (p.items.isEmpty) {
      return _EmptyHint(
        icon: AppIcons.notificationsNoneRounded,
        title: l10n.notificationsInboxEmptyTitle,
        body: l10n.notificationsInboxEmptyBody,
      );
    }
    return RefreshIndicator(
      onRefresh: () => p.loadInbox(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: EdgeInsets.only(
          top:
              AppSizes.sm +
              FloatingAppBar.contentTopInset(context) +
              kTextTabBarHeight,
          bottom: AppSizes.massive + AppSizes.xxxl,
        ),
        itemCount: p.items.length,
        separatorBuilder: (_, _) =>
            Container(height: 1, color: AppColors.hairline),
        itemBuilder: (_, i) => _NotificationTile(notification: p.items[i]),
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
    return InkWell(
      onTap: () {
        if (notification.isUnread) p.markRead(notification.id);
        // Quotation notifications deep-link into the quotations feature;
        // other kinds remain informational (mark-read only) for now.
        if (notification.kind.startsWith('QUOTATION_')) {
          _openQuotation(context);
        }
      },
      child: Container(
        color: notification.isUnread
            ? AppColors.brandSoft.withValues(alpha: 0.35)
            : null,
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
    final quotationId = raw is int
        ? raw
        : (raw == null ? null : int.tryParse('$raw'));

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
      padding: EdgeInsets.only(
        top:
            AppSizes.sm +
            FloatingAppBar.contentTopInset(context) +
            kTextTabBarHeight,
        bottom: AppSizes.massive + AppSizes.xxxl,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) =>
          Container(height: 1, color: AppColors.hairline),
      itemBuilder: (_, _) => const _NotificationTileSkeleton(),
    );
  }
}

class _NotificationTileSkeleton extends StatelessWidget {
  const _NotificationTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  const _IncomingTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.watch<NotificationsProvider>();
    if (p.incoming.isEmpty) {
      return _EmptyHint(
        icon: AppIcons.markEmailUnreadOutlined,
        title: l10n.notificationsIncomingEmptyTitle,
        body: l10n.notificationsIncomingEmptyBody,
      );
    }
    return RefreshIndicator(
      onRefresh: () => p.loadIncoming(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: EdgeInsets.only(
          top:
              AppSizes.sm +
              FloatingAppBar.contentTopInset(context) +
              kTextTabBarHeight,
          bottom: AppSizes.massive + AppSizes.xxxl,
        ),
        itemCount: p.incoming.length,
        separatorBuilder: (_, _) =>
            Container(height: 1, color: AppColors.hairline),
        itemBuilder: (_, i) => _IncomingInviteTile(invite: p.incoming[i]),
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

    return Padding(
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
              _StatusChip(status: invite.status),
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
  const _OutgoingTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final p = context.watch<NotificationsProvider>();
    if (p.outgoing.isEmpty) {
      return _EmptyHint(
        icon: AppIcons.outboxOutlined,
        title: l10n.notificationsOutgoingEmptyTitle,
        body: l10n.notificationsOutgoingEmptyBody,
      );
    }
    return RefreshIndicator(
      onRefresh: () => p.loadOutgoing(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: EdgeInsets.only(
          top:
              AppSizes.sm +
              FloatingAppBar.contentTopInset(context) +
              kTextTabBarHeight,
          bottom: AppSizes.massive + AppSizes.xxxl,
        ),
        itemCount: p.outgoing.length,
        separatorBuilder: (_, _) =>
            Container(height: 1, color: AppColors.hairline),
        itemBuilder: (_, i) {
          final invite = p.outgoing[i];
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
    final p = context.read<NotificationsProvider>();
    return Padding(
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(status: invite.status),
          if (invite.isPending)
            IconButton(
              tooltip: l10n.notificationsCancel,
              icon: const AppIcon(AppIcons.closeRounded, size: AppSizes.iconMd),
              onPressed: () async {
                try {
                  await p.cancel(invite.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.notificationsInvitationCancelled),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              },
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
