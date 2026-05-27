import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_hours_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_kyc_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_payouts_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_team_page.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// "Shop operations" hub — entry tiles for Hours/Vacation, Payouts,
/// KYC, and Team. Hours is fully wired; the other three are
/// scaffolds today (no backend) so the surfaces exist when the
/// payment + verification + multi-user features land.
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>().shop;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Shop operations')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.huge),
        children: [
          _OpsTile(
            icon: Icons.schedule_rounded,
            iconBg: AppColors.brandSoft,
            iconColor: AppColors.brandStrong,
            title: 'Hours & vacation mode',
            subtitle: shop?.vacationMode == true
                ? 'On vacation — new orders blocked'
                : 'Set opening hours and pause new orders.',
            trailing: shop?.vacationMode == true
                ? const AppStatusBadge(
                    label: 'On vacation',
                    tone: AppStatusTone.warning,
                    weight: AppStatusWeight.soft,
                    dense: true,
                  )
                : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopHoursPage()),
            ),
          ),
          _OpsTile(
            icon: Icons.account_balance_outlined,
            iconBg: AppColors.infoSoft,
            iconColor: AppColors.info,
            title: 'Payouts & settlement',
            subtitle:
                'Bank account + UPI for payouts. Wiring lands with '
                'the payment gateway.',
            trailing: const AppStatusBadge(
              label: 'Coming soon',
              tone: AppStatusTone.info,
              weight: AppStatusWeight.soft,
              dense: true,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopPayoutsPage()),
            ),
          ),
          _OpsTile(
            icon: Icons.verified_user_outlined,
            iconBg: AppColors.accentIndigoSoft,
            iconColor: AppColors.accentIndigo,
            title: 'KYC documents',
            subtitle:
                'PAN, GSTIN certificate, cancelled cheque. Required '
                'before payouts go live.',
            trailing: const AppStatusBadge(
              label: 'Coming soon',
              tone: AppStatusTone.info,
              weight: AppStatusWeight.soft,
              dense: true,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopKycPage()),
            ),
          ),
          _OpsTile(
            icon: Icons.group_outlined,
            iconBg: AppColors.accentRoseSoft,
            iconColor: AppColors.accentRose,
            title: 'Team & roles',
            subtitle:
                "Invite staff with scoped permissions. Single-user "
                "today; multi-user lands in the next release.",
            trailing: const AppStatusBadge(
              label: 'Coming soon',
              tone: AppStatusTone.info,
              weight: AppStatusWeight.soft,
              dense: true,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopTeamPage()),
            ),
          ),
        ],
      ),
    );
  }
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 20),
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
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.subtle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
