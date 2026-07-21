import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_hours_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_kyc_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_payouts_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_team_page.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/linked_account_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// "Shop operations" hub — entry tiles for Hours/Vacation, Payouts,
/// KYC, and Team. Hours and Payouts are fully wired (Payouts shows a
/// live onboarding status badge); KYC-documents and Team are still
/// scaffolds (no backend) so the surfaces exist when the verification +
/// multi-user features land.
class ShopOperationsPage extends StatefulWidget {
  const ShopOperationsPage({super.key});

  @override
  State<ShopOperationsPage> createState() => _ShopOperationsPageState();
}

class _ShopOperationsPageState extends State<ShopOperationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Refresh so the vacation-mode chip in the Hours tile reflects
      // the latest server state when the merchant returns from
      // editing.
      context.read<ShopProvider>().load();
      // Live payout status drives the Payouts tile badge (Set up / Under
      // review / Active). Only owners can read the linked-account status
      // (billing:manage is owner-only) — staff would just 403, and the
      // tile is hidden for them anyway, so skip the call.
      if (context.read<AuthProvider>().user?.canView('payouts') ?? false) {
        context.read<LinkedAccountProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shopProvider = context.watch<ShopProvider>();
    final shop = shopProvider.shop;
    final payouts = context.watch<LinkedAccountProvider>();
    final (canShop, canBilling, canTeam) =
        context.select<AuthProvider, (bool, bool, bool)>((a) {
      final u = a.user;
      return (
        u?.canView('shop') ?? false,
        u?.canView('payouts') ?? false,
        u?.canView('team') ?? false,
      );
    });

    final isLoading = shopProvider.isLoading || payouts.isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.shopOperationsTitle,
        actions: [
          AccessReloadButton(onReload: () => context.read<ShopProvider>().load()),
        ],
      ),
      // Show layout-mirroring skeleton while either provider is still loading.
      body: isLoading && shop == null
          ? const _OperationsSkeleton()
          : ListView(
        padding: EdgeInsets.only(
            top: AppSizes.sm + FloatingAppBar.contentTopInset(context),
            bottom: AppSizes.huge),
        children: [
          if (canShop)
            _OpsTile(
            icon: AppIcons.scheduleRounded,
            iconBg: AppColors.brandSoft,
            iconColor: AppColors.brandStrong,
            title: l10n.shopHoursTitle,
            subtitle: shop?.vacationMode == true
                ? l10n.shopOpsHoursOnVacation
                : l10n.shopOpsHoursSubtitle,
            trailing: shop?.vacationMode == true
                ? AppStatusBadge(
                    label: l10n.shopOnVacationBadge,
                    tone: AppStatusTone.warning,
                    weight: AppStatusWeight.soft,
                    dense: true,
                  )
                : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopHoursPage()),
            ),
          ),
          if (canBilling)
            _OpsTile(
            icon: AppIcons.accountBalanceOutlined,
            iconBg: AppColors.infoSoft,
            iconColor: AppColors.info,
            title: l10n.shopPayoutsTitle,
            subtitle: _payoutsSubtitle(l10n, payouts),
            trailing: _payoutsBadge(l10n, payouts),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopPayoutsPage()),
            ),
          ),
          if (canBilling)
            _OpsTile(
            icon: AppIcons.verifiedUserOutlined,
            iconBg: AppColors.accentIndigoSoft,
            iconColor: AppColors.accentIndigo,
            title: l10n.shopKycTitle,
            subtitle: l10n.shopOpsKycSubtitle,
            trailing: AppStatusBadge(
              label: l10n.shopComingSoonBadge,
              tone: AppStatusTone.info,
              weight: AppStatusWeight.soft,
              dense: true,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopKycPage()),
            ),
          ),
          if (canTeam)
            _OpsTile(
              icon: AppIcons.groupOutlined,
              iconBg: AppColors.accentRoseSoft,
              iconColor: AppColors.accentRose,
              title: l10n.shopTeamTitle,
              subtitle: l10n.shopOpsTeamSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShopTeamPage()),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets — private to this file
// ---------------------------------------------------------------------------

/// One shimmer tile that mirrors the shape of [_OpsTile]:
/// circle icon placeholder, two text lines, optional right-side badge block.
class _OpsTileSkeleton extends StatelessWidget {
  const _OpsTileSkeleton({this.showBadge = false});

  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          // Circle — icon placeholder
          AppShimmerBox(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            radius: AppSizes.avatarSm / 2,
          ),
          const SizedBox(width: AppSizes.md),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.55, height: 14),
                const SizedBox(height: 6),
                AppShimmerLine(widthFactor: 0.80, height: 11),
              ],
            ),
          ),
          if (showBadge) ...[
            const SizedBox(width: AppSizes.sm),
            AppShimmerBox(width: 64, height: 22, radius: 6),
          ],
          const SizedBox(width: AppSizes.sm),
          // Chevron placeholder
          AppShimmerBox(width: 16, height: 16, radius: 4),
        ],
      ),
    );
  }
}

/// Four skeleton tiles — shown while [ShopProvider] or
/// [LinkedAccountProvider] is still loading.
class _OperationsSkeleton extends StatelessWidget {
  const _OperationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
          top: AppSizes.sm + FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _OpsTileSkeleton(),
        _OpsTileSkeleton(showBadge: true),
        _OpsTileSkeleton(showBadge: true),
        _OpsTileSkeleton(),
      ],
    );
  }
}

String _payoutsSubtitle(AppLocalizations l10n, LinkedAccountProvider p) {
  if (!p.loaded) return l10n.shopOpsPayoutsLinkBank;
  if (p.hasDraft) return l10n.shopOpsPayoutsResume;
  final s = p.status;
  if (s == null) {
    return l10n.shopOpsPayoutsSetUp;
  }
  if (s.payoutsEnabled) {
    return l10n.shopOpsPayoutsActive;
  }
  return l10n.shopOpsPayoutsSubmitted;
}

Widget? _payoutsBadge(AppLocalizations l10n, LinkedAccountProvider p) {
  if (!p.loaded) return null;
  if (p.hasDraft) {
    return AppStatusBadge(
      label: l10n.shopInProgressBadge,
      tone: AppStatusTone.warning,
      weight: AppStatusWeight.soft,
      dense: true,
    );
  }
  final s = p.status;
  if (s == null) {
    return AppStatusBadge(
      label: l10n.shopSetUpBadge,
      tone: AppStatusTone.warning,
      weight: AppStatusWeight.soft,
      dense: true,
    );
  }
  if (s.payoutsEnabled) {
    return AppStatusBadge(
      label: l10n.shopActiveBadge,
      tone: AppStatusTone.success,
      weight: AppStatusWeight.soft,
      dense: true,
    );
  }
  return AppStatusBadge(
    label: l10n.shopUnderReviewBadge,
    tone: AppStatusTone.info,
    weight: AppStatusWeight.soft,
    dense: true,
  );
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.avatarSm,
              height: AppSizes.avatarSm,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: AppSizes.iconMd),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSizes.sm),
              trailing!,
            ],
            const SizedBox(width: AppSizes.sm),
            Icon(AppIcons.chevronRightRounded, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}
