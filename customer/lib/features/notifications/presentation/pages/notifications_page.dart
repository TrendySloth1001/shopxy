import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/notification.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/invitations_page.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_quotation_detail_page.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_quotations_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// V2 notifications inbox. Was a static mock with invented "delivered
/// today" / "price drop" rows until this build — now reads from
/// [NotificationsProvider] (the same store the legacy bell page uses).
/// The four tabs filter the same underlying list by the backend's
/// `kind` field via the [_NotificationBucket] heuristic below.
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
    _tabs = TabController(length: _NotificationBucket.values.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<NotificationsProvider>();
      p.loadInbox();
      // Pull pending invites alongside so the top-of-inbox callout shows
      // even when the user lands on the bell before opening MyShops.
      p.loadIncoming(status: 'PENDING');
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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        title: Text(p.unread > 0 ? 'Notifications (${p.unread})' : 'Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all_rounded),
            onPressed: p.unread == 0 ? null : p.markAllRead,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            for (final b in _NotificationBucket.values) Tab(text: b.label),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            p.loadInbox(),
            p.loadIncoming(status: 'PENDING'),
          ]);
        },
        child: Column(
          children: [
            const _PendingInviteBanner(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final bucket in _NotificationBucket.values)
                    _TabView(items: bucket.filter(p.items), provider: p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NotificationBucket {
  all,
  updates,
  offers,
  account;

  String get label => switch (this) {
        _NotificationBucket.all => 'All',
        _NotificationBucket.updates => 'Updates',
        _NotificationBucket.offers => 'Offers',
        _NotificationBucket.account => 'Account',
      };

  List<AppNotification> filter(List<AppNotification> all) {
    return switch (this) {
      _NotificationBucket.all => all,
      _NotificationBucket.updates =>
        all.where((n) => _isUpdate(n.kind)).toList(),
      _NotificationBucket.offers =>
        all.where((n) => _isOffer(n.kind)).toList(),
      _NotificationBucket.account =>
        all.where((n) => _isAccount(n.kind)).toList(),
    };
  }

  static bool _isUpdate(String k) =>
      k.startsWith('ORDER_') ||
      k.startsWith('PURCHASE_REQUEST_') ||
      k.startsWith('QUOTATION_') ||
      k == 'BACK_IN_STOCK' ||
      k == 'REVIEW_REQUEST';

  static bool _isOffer(String k) =>
      k == 'PRICE_DROP' ||
      k == 'FLASH_DEAL' ||
      k == 'DEAL' ||
      k == 'WISHLIST_DEAL';

  static bool _isAccount(String k) =>
      k.startsWith('INVITE_') ||
      k == 'PAYMENT_SUCCESS' ||
      k == 'PAYMENT_FAILED' ||
      k == 'REFUND' ||
      k == 'ADDRESS_VERIFIED';
}

class _TabView extends StatelessWidget {
  const _TabView({required this.items, required this.provider});
  final List<AppNotification> items;
  final NotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoadingInbox && items.isEmpty) {
      return const _NotificationListSkeleton();
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
                  const Icon(Icons.notifications_off_outlined,
                      size: AppSizes.iconHuge, color: AppColors.muted),
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    'No notifications here yet',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.hairline),
      itemBuilder: (_, i) => _NotificationTile(item: items[i], provider: provider),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading state
// ---------------------------------------------------------------------------

/// Renders [_count] placeholder rows that mirror the real [_NotificationTile]
/// layout while data is being fetched.
class _NotificationListSkeleton extends StatelessWidget {
  const _NotificationListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.hairline),
      itemBuilder: (_, _) => const _NotificationRowSkeleton(),
    );
  }
}

/// A single shimmer placeholder that mirrors one [_NotificationTile]:
/// 48 dp squircle icon on the left, then two or three shimmer lines.
class _NotificationRowSkeleton extends StatelessWidget {
  const _NotificationRowSkeleton();

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
          // Icon placeholder — 48 dp squircle
          AppShimmerBox(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with timestamp stub on the right
                Row(
                  children: [
                    Expanded(
                      child: AppShimmerLine(
                        widthFactor: 0.62,
                        height: 14,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    AppShimmerLine(
                      widthFactor: 0.18,
                      height: 12,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                // Body line
                AppShimmerLine(
                  widthFactor: 0.85,
                  height: 12,
                ),
                const SizedBox(height: 3),
                // Optional third line (shorter)
                AppShimmerLine(
                  widthFactor: 0.45,
                  height: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.provider});
  final AppNotification item;
  final NotificationsProvider provider;

  @override
  Widget build(BuildContext context) {
    final spec = _kindSpec(item.kind);
    return InkWell(
      onTap: () {
        if (item.isUnread) provider.markRead(item.id);
        // Invite notifications are actionable — route to the dedicated
        // page where the user can accept/decline rather than leaving
        // the tile as an informational dead-end.
        if (item.isInvite) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InvitationsPage()),
          );
        } else if (item.kind.startsWith('QUOTATION_')) {
          _openQuotation(context);
        }
      },
      child: Container(
        color: item.isUnread ? AppColors.brandSoft.withValues(alpha: 0.25) : null,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.xxxl,
              height: AppSizes.xxxl,
              decoration: ShapeDecoration(
                color: spec.tint,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(spec.icon, size: AppSizes.iconMd, color: spec.accent),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.black,
                                fontWeight: item.isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        _formatTime(item.createdAt),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  if (item.body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.body!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Routes a QUOTATION_* notification to the shop it belongs to.
  ///
  /// The notification `data` carries `partyId` + `quotationId`; the shop
  /// itself is resolved from the user's `/me/links` (ShopsProvider). We land
  /// on the shop's quotations list immediately for fast feedback, then — once
  /// the quotation list is loaded — push the exact quotation's detail on top
  /// so "back" naturally returns to the list.
  Future<void> _openQuotation(BuildContext context) async {
    final shopsProvider = context.read<ShopsProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final partyId = _asInt(item.data['partyId']);
    final quotationId = _asInt(item.data['quotationId']);

    if (shopsProvider.shops.isEmpty) {
      await shopsProvider.loadShops();
    }
    LinkedShop? match;
    for (final s in shopsProvider.shops) {
      if (s.role == ShopRole.party && s.id == partyId) {
        match = s;
        break;
      }
    }
    final shop = match;
    if (shop == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not find the shop for this quotation'),
        ),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute(builder: (_) => ShopQuotationsPage(shop: shop)),
    );
    if (quotationId == null) return;
    await shopsProvider.loadQuotations(shop);
    final quotes = shopsProvider.quotationsFor(shop) ?? const <ShopQuotation>[];
    for (final q in quotes) {
      if (q.id == quotationId) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => ShopQuotationDetailPage(shop: shop, quotation: q),
          ),
        );
        return;
      }
    }
  }

  static int? _asInt(dynamic v) =>
      v is int ? v : (v == null ? null : int.tryParse('$v'));

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    if (that == today) return DateFormat('HH:mm').format(t);
    if (today.difference(that).inDays == 1) return 'Yesterday';
    if (now.year == t.year) return DateFormat('d MMM').format(t);
    return DateFormat('d MMM yyyy').format(t);
  }

  static _IconSpec _kindSpec(String kind) {
    // All accents go through AppColors tokens so a future theme
    // swap (dark mode, brand re-skin) flows through. Map per kind:
    // orders → info, deals → warning/amber, refunds → success,
    // invites → indigo, restock → rose, default → muted.
    if (kind.startsWith('ORDER_') || kind.startsWith('PURCHASE_REQUEST_')) {
      return const _IconSpec(
        icon: Icons.local_shipping_outlined,
        tint: AppColors.infoSoft,
        accent: AppColors.info,
      );
    }
    if (kind == 'PRICE_DROP' || kind == 'WISHLIST_DEAL') {
      return const _IconSpec(
        icon: Icons.trending_down_rounded,
        tint: AppColors.successSoft,
        accent: AppColors.success,
      );
    }
    if (kind == 'FLASH_DEAL' || kind == 'DEAL') {
      return const _IconSpec(
        icon: Icons.bolt_rounded,
        tint: AppColors.accentAmberSoft,
        accent: AppColors.accentAmber,
      );
    }
    if (kind.startsWith('INVITE_')) {
      return const _IconSpec(
        icon: Icons.mail_outline_rounded,
        tint: AppColors.accentIndigoSoft,
        accent: AppColors.accentIndigo,
      );
    }
    if (kind == 'PAYMENT_SUCCESS' || kind == 'REFUND') {
      return const _IconSpec(
        icon: Icons.payments_outlined,
        tint: AppColors.successSoft,
        accent: AppColors.success,
      );
    }
    if (kind.startsWith('QUOTATION_')) {
      return const _IconSpec(
        icon: Icons.request_quote_outlined,
        tint: AppColors.brandSoft,
        accent: AppColors.brandStrong,
      );
    }
    if (kind == 'BACK_IN_STOCK') {
      return const _IconSpec(
        icon: Icons.inventory_2_outlined,
        tint: AppColors.accentRoseSoft,
        accent: AppColors.accentRose,
      );
    }
    return const _IconSpec(
      icon: Icons.notifications_none_rounded,
      tint: AppColors.surfaceTint,
      accent: AppColors.muted,
    );
  }
}

class _IconSpec {
  const _IconSpec({required this.icon, required this.tint, required this.accent});
  final IconData icon;
  final Color tint;
  final Color accent;
}

/// Persistent callout at the top of the inbox while the user has
/// unanswered invites. Tapping opens the full InvitationsPage where
/// they can accept/decline each one.
class _PendingInviteBanner extends StatelessWidget {
  const _PendingInviteBanner();

  @override
  Widget build(BuildContext context) {
    final pending = context.select<NotificationsProvider, int>(
      (p) => p.pendingIncoming.length,
    );
    if (pending == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: InkWell(
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusLg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InvitationsPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: ShapeDecoration(
            color: AppColors.brandSoft,
            shape: AppShapes.squircle(
              AppSizes.radiusLg,
              side: const BorderSide(color: AppColors.brand, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: AppSizes.xxxl,
                height: AppSizes.xxxl,
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  color: AppColors.white,
                  size: AppSizes.iconSm,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending == 1
                          ? 'You have 1 pending invitation'
                          : 'You have $pending pending invitations',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.brandStrong,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Tap to review and accept',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.brandStrong,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.brandStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
