import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/action_center.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/alerts.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/analytics.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/kpi_row.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/onboarding_checklist.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/operations.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/period_switcher.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/recent_activity.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/trend_card.dart';
import 'package:shopxy/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/linked_account_provider.dart';
import 'package:shopxy/features/shop/presentation/widgets/payout_setup_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';

/// Merchant dashboard — a 1:1 port of the merchant-web overview
/// (`merchant-web/src/features/dashboard`): period switcher, KPI row, sales
/// trend chart, analytics pies, action centre, operations strip and the recent
/// activity feed. Responsive from phone to wide tablet.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  /// Guards the one-time payout-setup nudge so a rebuild can't stack sheets.
  bool _payoutNudgeScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user?.canView('dashboard') ?? false) {
        context.read<DashboardProvider>().bootstrap();
      }
      context.read<NotificationsProvider>().loadIncoming(status: 'PENDING');
      if (user?.canView('orders') ?? false) {
        context.read<OrdersProvider>().refreshPendingCount();
      }
      if (user?.canView('payouts') ?? false) {
        context.read<LinkedAccountProvider>().load();
      }
    });
  }

  void _maybeNudgePayouts(LinkedAccountProvider payouts) {
    if (_payoutNudgeScheduled || !payouts.shouldPrompt) return;
    _payoutNudgeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !payouts.shouldPrompt) return;
      await showPayoutSetupSheet(context, hasDraft: payouts.hasDraft);
      if (mounted) payouts.dismissPrompt();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final stats = provider.stats;
    final canViewDashboard = context.select<AuthProvider, bool>(
        (a) => a.user?.canView('dashboard') ?? false);
    if (canViewDashboard) {
      _maybeNudgePayouts(context.watch<LinkedAccountProvider>());
    }

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text(AppStrings.appName),
        actions: [
          const NotificationBell(),
          AccessReloadButton(onReload: () => provider.loadStats()),
        ],
      ),
      body: !canViewDashboard
          ? const NoAccessView(
              title: 'Dashboard hidden',
              message:
                  'Your role doesn\'t include the dashboard overview. Ask an '
                  'owner if you need it.',
            )
          : stats == null
              ? (provider.error != null
                  ? AppErrorView(onRetry: () => provider.loadStats())
                  : const _DashboardSkeleton())
              : RefreshIndicator(
                  onRefresh: () => provider.loadStats(),
                  color: AppColors.brand,
                  backgroundColor: AppColors.surface,
                  child: _DashboardScroll(
                    provider: provider,
                    stats: stats,
                  ),
                ),
    );
  }
}

/// Horizontal page padding — 16 on phones, 24 on wider screens (web `md:px-xxl`).
double _hPad(double w) => w >= 768 ? AppSizes.xxl : AppSizes.lg;

class _DashboardScroll extends StatelessWidget {
  const _DashboardScroll({required this.provider, required this.stats});
  final DashboardProvider provider;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = _hPad(c.maxWidth);
        return ListView(
          padding: EdgeInsets.fromLTRB(
              pad, AppSizes.xxl, pad, AppSizes.huge),
          children: [
            _Header(provider: provider, width: c.maxWidth),
            const _PendingInviteCallout(),
            const SizedBox(height: AppSizes.xxl),
            _DashboardBody(provider: provider, stats: stats),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider, required this.width});
  final DashboardProvider provider;
  final double width;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return AppStrings.greetingMorning;
    if (h < 17) return AppStrings.greetingAfternoon;
    return AppStrings.greetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, ({String? name, String? shop})>(
        (a) => (name: a.user?.name, shop: a.user?.shopName));
    final firstName =
        (user.name != null && user.name!.trim().isNotEmpty)
            ? ', ${user.name!.trim().split(' ').first}'
            : '';

    final greetingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${_greeting()}$firstName', style: DashText.headlineMd),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Here’s how ${user.shop ?? 'your shop'} is doing.',
          style: DashText.bodyMd.copyWith(color: AppColors.muted),
        ),
      ],
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PeriodSwitcher(
          value: provider.period,
          onChanged: (p) => provider.changePeriod(p),
        ),
        const SizedBox(width: AppSizes.sm),
        _RefreshButton(provider: provider),
      ],
    );

    // Stack on narrow screens, spread on wide (web `flex-wrap justify-between`).
    if (width < Bp.sm) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          greetingBlock,
          const SizedBox(height: AppSizes.md),
          controls,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: greetingBlock),
        const SizedBox(width: AppSizes.md),
        controls,
      ],
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.provider});
  final DashboardProvider provider;

  @override
  Widget build(BuildContext context) {
    final busy = provider.isLoading || provider.isRefreshing;
    return Material(
      color: AppColors.canvas,
      shape: AppShapes.squircle(AppSizes.radiusButton,
          side: BorderSide(color: AppColors.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : () => provider.loadStats(),
        child: SizedBox(
          width: 36,
          height: 36,
          child: _SpinningRefresh(spinning: busy),
        ),
      ),
    );
  }
}

class _SpinningRefresh extends StatefulWidget {
  const _SpinningRefresh({required this.spinning});
  final bool spinning;

  @override
  State<_SpinningRefresh> createState() => _SpinningRefreshState();
}

class _SpinningRefreshState extends State<_SpinningRefresh>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));

  @override
  void didUpdateWidget(_SpinningRefresh old) {
    super.didUpdateWidget(old);
    if (widget.spinning) {
      _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Icon(Icons.refresh_rounded,
          size: AppSizes.iconSm, color: AppColors.muted),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.provider, required this.stats});
  final DashboardProvider provider;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppSizes.xxl);

    if (stats.isFresh) {
      final payouts = context.watch<LinkedAccountProvider>();
      final payoutsEnabled =
          !payouts.loaded ? true : (payouts.status?.payoutsEnabled ?? false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats.alerts.isNotEmpty) ...[
            Alerts(alerts: stats.alerts),
            gap,
          ],
          OnboardingChecklist(
            onboarding: stats.onboarding,
            payoutsEnabled: payoutsEnabled,
          ),
        ],
      );
    }

    final money = <Widget>[
      if (stats.kpis != null) KpiRow(kpis: stats.kpis!),
      if (stats.trend != null) TrendCard(trend: stats.trend!),
      if (stats.insights != null) Analytics(insights: stats.insights!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.alerts.isNotEmpty) ...[
          Alerts(alerts: stats.alerts),
          gap,
        ],
        // Period-scoped money sections dim while a new period loads.
        if (money.isNotEmpty) ...[
          _DimWhileRefreshing(
            refreshing: provider.isRefreshing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < money.length; i++) ...[
                  if (i > 0) gap,
                  money[i],
                ],
              ],
            ),
          ),
          gap,
        ],
        ActionCenter(queue: stats.actionQueue),
        gap,
        Operations(operations: stats.operations),
        gap,
        RecentActivity(transactions: stats.recent),
      ],
    );
  }
}

class _DimWhileRefreshing extends StatelessWidget {
  const _DimWhileRefreshing({required this.refreshing, required this.child});
  final bool refreshing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: refreshing,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: refreshing ? 0.6 : 1,
        child: child,
      ),
    );
  }
}

/// First-login pending-invite callout — links to the notifications screen.
class _PendingInviteCallout extends StatelessWidget {
  const _PendingInviteCallout();

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsProvider>();
    final pending = n.pendingIncoming;
    if (pending.isEmpty) return const SizedBox.shrink();
    final count = pending.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.lg),
      child: Material(
        color: AppColors.tileBg(AppColors.brandSoft),
        shape: AppShapes.squircle(AppSizes.radiusLg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: AppSizes.sm),
            child: Row(
              children: [
                Icon(Icons.mark_email_unread_outlined,
                    size: 18, color: AppColors.brandStrong),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Text(
                    'You have $count pending invitation${count == 1 ? '' : 's'} '
                    '— review and accept.',
                    style:
                        DashText.bodyMd.copyWith(color: AppColors.brandStrong),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Text('View',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandStrong)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = _hPad(c.maxWidth);
        final kpiCols = responsiveCols(c.maxWidth - pad * 2, base: 2, lg: 4);
        final actionCols =
            responsiveCols(c.maxWidth - pad * 2, base: 2, lg: 3, xl: 6);
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, AppSizes.xxl, pad, AppSizes.huge),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const AppShimmerLine(widthFactor: 0.5, height: 26),
            const SizedBox(height: AppSizes.sm),
            const AppShimmerLine(widthFactor: 0.7, height: 14),
            const SizedBox(height: AppSizes.xxl),
            ResponsiveGrid(
              columns: kpiCols,
              childAspectRatio: 1.4,
              children: [for (var i = 0; i < kpiCols; i++) _box(112)],
            ),
            const SizedBox(height: AppSizes.xxl),
            _box(300),
            const SizedBox(height: AppSizes.xxl),
            ResponsiveGrid(
              columns: actionCols,
              childAspectRatio: 2.4,
              children: [for (var i = 0; i < actionCols; i++) _box(64)],
            ),
          ],
        );
      },
    );
  }

  Widget _box(double h) => AppShimmerBox(height: h, radius: AppSizes.radiusLg);
}
