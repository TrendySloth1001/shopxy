import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/notifications/domain/entities/notification.dart';
import 'package:shopxy/features/notifications/presentation/pages/send_invite_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

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
    final p = context.watch<NotificationsProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: p.unread > 0 ? 'Inbox (${p.unread})' : 'Inbox'),
            Tab(
              text: p.pendingIncoming.isNotEmpty
                  ? 'Invites (${p.pendingIncoming.length})'
                  : 'Invites',
            ),
            const Tab(text: 'Sent'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: p.unread == 0 ? null : p.markAllRead,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SendInvitePage()),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _InboxTab(),
          _IncomingTab(),
          _OutgoingTab(),
        ],
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
    final p = context.watch<NotificationsProvider>();
    if (p.isLoadingInbox && p.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.items.isEmpty) {
      return const _EmptyHint(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        body: 'When something happens — like an invitation reply — you\'ll see it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => p.loadInbox(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: AppSizes.sm, bottom: 96),
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
      },
      child: Container(
        color: notification.isUnread ? AppColors.brandSoft.withValues(alpha: 0.35) : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: ShapeDecoration(
                color: accent.$2,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(accent.$3, size: 18, color: accent.$1),
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
                      fontWeight:
                          notification.isUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (notification.body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.body!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    DateFormat('d MMM · hh:mm a').format(notification.createdAt.toLocal()),
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
                margin: const EdgeInsets.only(left: AppSizes.sm, top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  (Color fg, Color bg, IconData icon) _accentFor(String kind) {
    switch (kind) {
      case 'INVITE_RECEIVED':
        return (AppColors.brandStrong, AppColors.brandSoft, Icons.mail_outline_rounded);
      case 'INVITE_ACCEPTED':
        return (AppColors.success, AppColors.successSoft, Icons.check_circle_outline_rounded);
      case 'INVITE_DECLINED':
        return (AppColors.warning, AppColors.warningSoft, Icons.cancel_outlined);
      case 'INVITE_CANCELLED':
        return (AppColors.muted, AppColors.heroPanel, Icons.cancel_schedule_send_outlined);
      default:
        return (AppColors.accentIndigo, AppColors.accentIndigoSoft, Icons.notifications_none_rounded);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────
// Incoming invitations
// ─────────────────────────────────────────────────────────────────────

class _IncomingTab extends StatelessWidget {
  const _IncomingTab();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationsProvider>();
    if (p.incoming.isEmpty) {
      return const _EmptyHint(
        icon: Icons.mark_email_unread_outlined,
        title: 'No invitations',
        body: 'When a shop invites you as a party or vendor, you\'ll see the request here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => p.loadIncoming(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: AppSizes.sm, bottom: 96),
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
    final theme = Theme.of(context);
    final p = context.read<NotificationsProvider>();
    final shopName = invite.fromShopName ?? invite.fromUserName ?? 'A shop';
    final roleLabel = invite.isParty ? 'party (customer)' : 'vendor (supplier)';

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
                width: 36,
                height: 36,
                decoration: ShapeDecoration(
                  color: invite.isParty
                      ? AppColors.accentRoseSoft
                      : AppColors.accentIndigoSoft,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(
                  invite.isParty ? Icons.groups_outlined : Icons.storefront_outlined,
                  color: invite.isParty
                      ? AppColors.accentRose
                      : AppColors.accentIndigo,
                  size: 18,
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
                      'wants to add you as their $roleLabel'
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
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _accept(context, p),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Accept'),
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
    try {
      await p.accept(invite.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation accepted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _decline(BuildContext context, NotificationsProvider p) async {
    try {
      await p.decline(invite.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation declined')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
    final p = context.watch<NotificationsProvider>();
    if (p.outgoing.isEmpty) {
      return const _EmptyHint(
        icon: Icons.outbox_outlined,
        title: 'No invitations sent yet',
        body: 'Tap the Invite button to invite a party or vendor by email.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => p.loadOutgoing(),
      color: AppColors.brand,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: AppSizes.sm, bottom: 96),
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
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: invite.isParty
                  ? AppColors.accentRoseSoft
                  : AppColors.accentIndigoSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(
              invite.isParty ? Icons.groups_outlined : Icons.storefront_outlined,
              color: invite.isParty
                  ? AppColors.accentRose
                  : AppColors.accentIndigo,
              size: 18,
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
                  invite.displayName ?? (invite.isParty ? 'Party' : 'Vendor'),
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
              tooltip: 'Cancel',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () async {
                try {
                  await p.cancel(invite.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation cancelled')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
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
    final (label, fg, bg) = switch (status) {
      InviteStatus.pending => ('Pending', AppColors.warning, AppColors.warningSoft),
      InviteStatus.accepted => ('Accepted', AppColors.success, AppColors.successSoft),
      InviteStatus.declined => ('Declined', AppColors.muted, AppColors.heroPanel),
      InviteStatus.cancelled => ('Cancelled', AppColors.muted, AppColors.heroPanel),
      InviteStatus.expired => ('Expired', AppColors.error, AppColors.errorSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 2,
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
  const _EmptyHint({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusLg),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.muted, size: 28),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
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
    );
  }
}
