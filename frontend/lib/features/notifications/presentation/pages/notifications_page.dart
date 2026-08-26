import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/notifications/domain/entities/notification.dart';
import 'package:shopxy/features/notifications/presentation/pages/invitations_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/notifications/presentation/widgets/empty_hint.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotation_detail_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotations_page.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/section_divider.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _inboxScrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _inboxHaptics;

  @override
  void initState() {
    super.initState();
    _inboxHaptics = ScrollBoundaryHaptics(_inboxScrollCtrl);
    _inboxScrollCtrl.addListener(_maybeLoadMoreInbox);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsProvider>().loadInbox();
    });
  }

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
    _inboxHaptics.dispose();
    _inboxScrollCtrl.removeListener(_maybeLoadMoreInbox);
    _inboxScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = context.select<NotificationsProvider, int>((p) => p.unread);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: unread > 0
            ? '${l10n.notificationsTitle} ($unread)'
            : l10n.notificationsTitle,
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
      body: _InboxTab(controller: _inboxScrollCtrl),
    );
  }
}

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
      return EmptyHint(
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
          AppSizes.sm + FloatingAppBar.contentTopInset(context),
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
          final date = notification.createdAt.toLocal();
          final newDay = i == 0 ||
              !SectionDivider.isSameDay(
                date,
                slice.items[i - 1].createdAt.toLocal(),
              );
          final tile = _NotificationTile(notification: notification);
          if (!newDay) return tile;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [SectionDivider.date(date), tile],
          );
        },
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
          if (notification.kind.startsWith('QUOTATION_')) {
            _openQuotation(context);
          } else if (notification.isInvite) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvitationsPage(
                  initialTab: notification.kind == 'INVITE_RECEIVED' ? 0 : 1,
                ),
              ),
            );
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

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm + FloatingAppBar.contentTopInset(context),
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
                AppShimmerLine(widthFactor: 0.55, height: 14),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.80, height: 12),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.35, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
