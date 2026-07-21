import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/widgets/invite_card.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// Dedicated screen for invitations addressed to the current user. Two
/// tabs — Pending (actionable) and History — both read from
/// [NotificationsProvider]'s `incoming` list. Tapping an INVITE
/// notification in the inbox routes here. Each row renders via the
/// shared [InviteCard], same as the home preview, so the visual
/// language stays consistent across surfaces.
class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loadingIncoming = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<NotificationsProvider>().loadIncoming();
      if (mounted) setState(() => _loadingIncoming = false);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loadingIncoming = true);
    await context.read<NotificationsProvider>().loadIncoming();
    if (mounted) setState(() => _loadingIncoming = false);
  }

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
            Tab(
              text:
                  pending.isEmpty ? 'Pending' : 'Pending (${pending.length})',
            ),
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
              isLoading: _loadingIncoming,
            ),
            _InvitationList(
              items: history,
              emptyTitle: 'No past invitations',
              emptyHint: 'Accepted and declined invitations will appear here.',
              isActionable: false,
              isLoading: _loadingIncoming,
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
    required this.isLoading,
  });
  final List<Invitation> items;
  final String emptyTitle;
  final String emptyHint;
  final bool isActionable;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading && items.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        itemCount: 4,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.md),
        itemBuilder: (context, index) => const _InviteCardSkeleton(),
      );
    }

    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSizes.productImageSize),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
              child: Column(
                children: [
                  const Icon(
                    AppIcons.markEmailUnreadOutlined,
                    size: AppSizes.iconHuge,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    emptyTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    emptyHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
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
      itemBuilder: (_, i) => _ActionableInviteRow(
        invite: items[i],
        actionable: isActionable,
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

/// Layout-mirroring placeholder for a single [InviteCard] row shown while
/// [NotificationsProvider.isLoadingIncoming] is true and no data is cached yet.
/// Mirrors: 86dp banner, overlapping circular logo, title + subtitle lines,
/// optional message box shimmer, and two action-button shimmers.
class _InviteCardSkeleton extends StatelessWidget {
  const _InviteCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.hairline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner (86dp) ────────────────────────────────────────────────
          AppShimmerBox(width: double.infinity, height: 86, radius: 0),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              0,
              AppSizes.md,
              AppSizes.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo overlapping banner + title/subtitle lines ─────────
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Circular logo
                      AppShimmerBox(
                        width: AppSizes.avatarMd,
                        height: AppSizes.avatarMd,
                        radius: AppSizes.radiusMd,
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.only(top: AppSizes.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status chip placeholder
                              AppShimmerBox(
                                width: 60,
                                height: 18,
                                radius: AppSizes.radiusFull,
                              ),
                              const SizedBox(height: AppSizes.sm),
                              // Title line
                              AppShimmerLine(
                                widthFactor: 0.85,
                                height: 14,
                              ),
                              const SizedBox(height: AppSizes.xs),
                              // Subtitle line
                              AppShimmerLine(
                                widthFactor: 0.55,
                                height: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Optional message box shimmer ─────────────────────────
                Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const AppShimmerBox(
                    width: double.infinity,
                    height: 44,
                    radius: AppSizes.radiusSm,
                  ),
                ),

                const SizedBox(height: AppSizes.md),

                // ── Action buttons ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: AppShimmerBox(
                        width: double.infinity,
                        height: AppSizes.huge,
                        radius: AppSizes.radiusMd,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      flex: 2,
                      child: AppShimmerBox(
                        width: double.infinity,
                        height: AppSizes.huge,
                        radius: AppSizes.radiusMd,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── End skeleton ──────────────────────────────────────────────────────────────

class _ActionableInviteRow extends StatefulWidget {
  const _ActionableInviteRow({
    required this.invite,
    required this.actionable,
  });
  final Invitation invite;
  final bool actionable;

  @override
  State<_ActionableInviteRow> createState() => _ActionableInviteRowState();
}

class _ActionableInviteRowState extends State<_ActionableInviteRow> {
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
          content: Text(friendlyError(e)),
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
    return InviteCard(
      invite: widget.invite,
      busy: _busy,
      actionable: widget.actionable,
      showExpiry: widget.actionable,
      showNewBadge: false,
      onAccept: widget.actionable ? () => _act(true) : null,
      onDecline: widget.actionable ? () => _act(false) : null,
    );
  }
}
