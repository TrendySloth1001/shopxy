import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy/features/profile/presentation/pages/profile_page.dart';
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
import 'package:shopxy/features/profile/presentation/widgets/gst_effective_date_sheet.dart';
import 'package:intl/intl.dart';
import 'package:shopxy/features/shop/presentation/providers/linked_account_provider.dart';
import 'package:shopxy/features/shop/presentation/widgets/payout_setup_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

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
  /// Guards the one-time startup-nudge sequence so a rebuild can't stack
  /// sheets or re-run the chain mid-way.
  bool _startupNudgesScheduled = false;
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
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

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Runs the startup nudge sheets ONE AT A TIME, never stacked — payout
  /// setup first (if due), then the GST-effective-date declaration (if
  /// due), only after the payout sheet has fully resolved either way.
  void _maybeRunStartupNudges(LinkedAccountProvider payouts, AuthProvider auth) {
    if (_startupNudgesScheduled) return;
    if (!payouts.shouldPrompt && !auth.shouldPromptGstEffectiveDate) return;
    _startupNudgesScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (payouts.shouldPrompt) {
        await showPayoutSetupSheet(context, hasDraft: payouts.hasDraft);
        if (mounted) payouts.dismissPrompt();
      }
      if (!mounted || !auth.shouldPromptGstEffectiveDate) return;
      final declared = await showGstEffectiveDateSheet(context);
      if (!mounted) return;
      if (declared != null) {
        try {
          await auth.updateProfile(
            gstEffectiveFrom: DateFormat('yyyy-MM-dd').format(declared),
          );
        } catch (_) {
          // Best-effort — the merchant can still set it from Edit profile;
          // don't block the dashboard on a transient save failure here.
        }
        if (mounted) auth.dismissGstEffectiveDatePrompt();
        return;
      }
      // Skipped — take them straight to the exact setting instead of just
      // dropping the nudge, so declaring the date is still one tap away.
      auth.dismissGstEffectiveDatePrompt();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const EditProfilePage(focusField: ProfileField.gstEffectiveFrom),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<DashboardProvider>();
    final stats = provider.stats;
    final canViewDashboard = context.select<AuthProvider, bool>(
      (a) => a.user?.canView('dashboard') ?? false,
    );
    if (canViewDashboard) {
      _maybeRunStartupNudges(
        context.watch<LinkedAccountProvider>(),
        context.watch<AuthProvider>(),
      );
    }
    // The profile action shows the user's actual avatar (their photo, or a
    // colored monogram fallback) rather than a generic person glyph.
    final profile = context
        .select<AuthProvider, ({String? name, String? avatarUrl})>(
          (a) => (name: a.user?.name, avatarUrl: a.user?.avatarUrl),
        );

    return Scaffold(
      // Let the page scroll *behind* the floating app bar (transparent) —
      // content passes under the islands. The scroll adds the bar's inset
      // as top padding so nothing hides beneath it at rest.
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar.brand(
        actions: [
          const NotificationBell(),
          // Profile shortcut — the user's avatar opens the Profile page.
          // (Profile is no longer a bottom-nav tab.)
          IconButton(
            tooltip: l10n.navProfile,
            icon: ProfileAvatar(
              name: profile.name ?? '',
              imageUrl: profile.avatarUrl,
              size: 30,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
        ],
      ),
      body: !canViewDashboard
          ? NoAccessView(
              title: l10n.dashboardHiddenTitle,
              message: l10n.dashboardHiddenMessage,
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
                controller: _scrollCtrl,
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
  const _DashboardScroll({
    required this.controller,
    required this.provider,
    required this.stats,
  });
  final ScrollController controller;
  final DashboardProvider provider;
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = _hPad(c.maxWidth);
        // With extendBodyBehindAppBar the body starts at y=0, so add the
        // app bar's inset (status bar + island band) to the top padding.
        final topInset = FloatingAppBar.contentTopInset(context) + AppSizes.xxl;
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            pad,
            topInset,
            pad,
            FloatingBottomNav.contentBottomInset(context) + AppSizes.sm,
          ),
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

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    if (h < 12) return l10n.dashboardGreetingMorning;
    if (h < 17) return l10n.dashboardGreetingAfternoon;
    return l10n.dashboardGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.select<AuthProvider, ({String? name, String? shop})>(
      (a) => (name: a.user?.name, shop: a.user?.shopName),
    );
    final greeting = _greeting(l10n);
    final hasName = user.name != null && user.name!.trim().isNotEmpty;
    final greetingLine = hasName
        ? l10n.dashboardGreetingWithName(
            greeting,
            user.name!.trim().split(' ').first,
          )
        : greeting;
    final shopName = user.shop ?? l10n.dashboardYourShop;

    final greetingBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(greetingLine, style: DashText.headlineMd),
        const SizedBox(height: AppSizes.xs),
        Text(
          l10n.dashboardShopStatus(shopName),
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
      shape: AppShapes.squircle(
        AppSizes.radiusButton,
        side: BorderSide(color: AppColors.hairline),
      ),
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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

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
      child: AppIcon(
        AppIcons.refreshRounded,
        size: AppSizes.iconSm,
        color: AppColors.muted,
      ),
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
      final payoutsEnabled = !payouts.loaded
          ? true
          : (payouts.status?.payoutsEnabled ?? false);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats.alerts.isNotEmpty) ...[Alerts(alerts: stats.alerts), gap],
          OnboardingChecklist(
            onboarding: stats.onboarding,
            payoutsEnabled: payoutsEnabled,
          ),
        ],
      );
    }

    final money = <Widget>[
      if (stats.kpis != null)
        KpiRow(kpis: stats.kpis!, period: provider.period),
      if (stats.trend != null) TrendCard(trend: stats.trend!),
      if (stats.insights != null) Analytics(insights: stats.insights!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stats.alerts.isNotEmpty) ...[Alerts(alerts: stats.alerts), gap],
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
    final l10n = AppLocalizations.of(context);
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
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.markEmailUnreadOutlined,
                  size: 18,
                  color: AppColors.brandStrong,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Text(
                    count == 1
                        ? l10n.dashboardPendingInviteOne
                        : l10n.dashboardPendingInviteMany('$count'),
                    style: DashText.bodyMd.copyWith(
                      color: AppColors.brandStrong,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  l10n.dashboardView,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandStrong,
                  ),
                ),
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
        final actionCols = responsiveCols(
          c.maxWidth - pad * 2,
          base: 2,
          lg: 3,
          xl: 6,
        );
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
