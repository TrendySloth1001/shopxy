import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/notification.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

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
      context.read<NotificationsProvider>().loadInbox();
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
        onRefresh: () => p.loadInbox(),
        child: TabBarView(
          controller: _tabs,
          children: [
            for (final bucket in _NotificationBucket.values)
              _TabView(items: bucket.filter(p.items), provider: p),
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
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.xl),
              child: Column(
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 48, color: AppColors.muted),
                  SizedBox(height: AppSizes.sm),
                  Text(
                    'No notifications here yet',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.hairline),
      itemBuilder: (_, i) => _NotificationTile(item: items[i], provider: provider),
    );
  }
}

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
      },
      child: Container(
        color: item.isUnread ? AppColors.brandSoft.withValues(alpha: 0.25) : null,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: ShapeDecoration(
                color: spec.tint,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(spec.icon, size: 18, color: spec.accent),
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
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: 14,
                            fontWeight: item.isUnread
                                ? FontWeight.w800
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        _formatTime(item.createdAt),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (item.body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.body!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
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
