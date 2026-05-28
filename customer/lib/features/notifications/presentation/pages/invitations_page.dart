import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Dedicated screen for invitations addressed to the current user. Two
/// tabs — Pending (actionable) and History — both read from
/// [NotificationsProvider]'s `incoming` list. Tapping an INVITE
/// notification in the inbox routes here.
class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsProvider>().loadIncoming();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() =>
      context.read<NotificationsProvider>().loadIncoming();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<NotificationsProvider>();
    final pending = p.incoming.where((i) => i.isPending).toList();
    final history = p.incoming.where((i) => !i.isPending).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        title: const Text('Invitations'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: pending.isEmpty ? 'Pending' : 'Pending (${pending.length})'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: TabBarView(
          controller: _tabs,
          children: [
            _InvitationList(
              items: pending,
              emptyTitle: 'No pending invitations',
              emptyHint:
                  'When a shop invites you to view their ledger, it will show up here.',
              isActionable: true,
            ),
            _InvitationList(
              items: history,
              emptyTitle: 'No past invitations',
              emptyHint: 'Accepted and declined invitations will appear here.',
              isActionable: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationList extends StatelessWidget {
  const _InvitationList({
    required this.items,
    required this.emptyTitle,
    required this.emptyHint,
    required this.isActionable,
  });
  final List<Invitation> items;
  final String emptyTitle;
  final String emptyHint;
  final bool isActionable;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
              child: Column(
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    emptyTitle,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    emptyHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, i) => _InvitationCard(
        invite: items[i],
        actionable: isActionable,
      ),
    );
  }
}

class _InvitationCard extends StatefulWidget {
  const _InvitationCard({required this.invite, required this.actionable});
  final Invitation invite;
  final bool actionable;

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  bool _busy = false;

  Future<void> _act(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<NotificationsProvider>();
    final shopsProvider = context.read<ShopsProvider>();
    try {
      if (accept) {
        await provider.accept(widget.invite.id);
        // A new linked shop just appeared — refresh the shops list so
        // the user's "My shops" tab reflects it without a manual pull.
        await shopsProvider.loadShops();
      } else {
        await provider.decline(widget.invite.id);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Invitation accepted — you can now view this ledger.'
              : 'Invitation declined.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invite;
    final isParty = inv.isParty;
    final accent = isParty ? AppColors.accentRose : AppColors.accentIndigo;
    final accentSoft = isParty ? AppColors.accentRoseSoft : AppColors.accentIndigoSoft;
    final shopName = inv.fromShopName ?? inv.fromUserName ?? 'A shop';
    final roleLabel = isParty ? 'Customer' : 'Supplier';

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: accentSoft,
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  shopName.isEmpty ? '?' : shopName[0].toUpperCase(),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: ShapeDecoration(
                            color: accentSoft,
                            shape: AppShapes.squircle(AppSizes.radiusFull),
                          ),
                          child: Text(
                            'as $roleLabel',
                            style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Flexible(
                          child: Text(
                            _formatDate(inv.createdAt),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!widget.actionable) _StatusChip(status: inv.status),
            ],
          ),
          if (inv.displayName != null) ...[
            const SizedBox(height: AppSizes.md),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'You\'ll be linked as',
              value: inv.displayName!,
            ),
          ],
          if (inv.message != null && inv.message!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.format_quote_rounded,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Expanded(
                    child: Text(
                      inv.message!,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.actionable) ...[
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _act(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.black,
                      side: const BorderSide(color: AppColors.hairline),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.md,
                      ),
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _act(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.md,
                      ),
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Text(
                            'Accept',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Expires ${_formatExpiry(inv.expiresAt)}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (now.year == t.year) return DateFormat('d MMM').format(t);
    return DateFormat('d MMM yyyy').format(t);
  }

  static String _formatExpiry(DateTime t) {
    final diff = t.difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    if (diff.inDays >= 2) return 'in ${diff.inDays} days';
    if (diff.inHours >= 2) return 'in ${diff.inHours} hours';
    return 'soon';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: AppSizes.xs),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(text: '$label '),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final InviteStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, soft) = switch (status) {
      InviteStatus.accepted => ('Accepted', AppColors.success, AppColors.successSoft),
      InviteStatus.declined => ('Declined', AppColors.muted, AppColors.heroPanel),
      InviteStatus.cancelled => ('Cancelled', AppColors.muted, AppColors.heroPanel),
      InviteStatus.expired => ('Expired', AppColors.warning, AppColors.warningSoft),
      InviteStatus.pending => ('Pending', AppColors.info, AppColors.infoSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: soft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
