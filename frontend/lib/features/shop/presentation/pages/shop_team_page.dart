import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// Team / staff scaffold — UI shell only. Today every shop is
/// single-user (one OWNER); this page previews the multi-user
/// surface so when the role system lands the screen is already in
/// place. Lists the owner + greys out the Invite button.
class ShopTeamPage extends StatelessWidget {
  const ShopTeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Team & roles'),
        actions: [
          IconButton(
            tooltip: 'Invite (coming soon)',
            onPressed: null,
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.huge),
        children: [
          Material(
            color: AppColors.infoSoft,
            shape: AppShapes.squircle(AppSizes.radiusMd),
            child: const Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.info),
                  SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      'Today every shop has one owner. Inviting staff with '
                      'scoped permissions (Manager, Stockist, Cashier) lands '
                      "with the role system in the next release.",
                      style:
                          TextStyle(color: AppColors.info, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            'CURRENT TEAM',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: AppSizes.sm),
          Material(
            color: AppColors.white,
            shape: AppShapes.squircle(AppSizes.radiusMd),
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.brandSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  (user?.name.isNotEmpty ?? false)
                      ? user!.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(
                user?.name ?? 'You',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(user?.email ?? ''),
              trailing: const AppStatusBadge(
                label: 'Owner',
                tone: AppStatusTone.info,
                weight: AppStatusWeight.soft,
                dense: true,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Text(
            'ROLES (PREVIEW)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: AppSizes.sm),
          _RoleCard(
            title: 'Manager',
            scope: 'Full access except billing + team.',
          ),
          _RoleCard(
            title: 'Stockist',
            scope:
                'Inventory + purchases. Cannot edit prices, products, '
                'or orders.',
          ),
          _RoleCard(
            title: 'Cashier',
            scope: 'Create invoices + accept payments. Read-only elsewhere.',
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.title, required this.scope});
  final String title;
  final String scope;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.black, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(scope,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
