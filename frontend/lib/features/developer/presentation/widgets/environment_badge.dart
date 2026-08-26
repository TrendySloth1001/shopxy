import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/config/app_environment.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/developer/presentation/pages/environment_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().user?.email;
    if (!isDeveloperAccount(email)) return const SizedBox.shrink();

    if (AppEnvironments.overrideBaseUrl == null) return const SizedBox.shrink();

    final env = AppEnvironments.matching(AppConfig.apiBaseUrl);
    if (env?.id == AppEnvironments.production.id) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.warningSoft,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EnvironmentPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.warningAmberRounded,
                size: AppSizes.iconSm - 2,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                env?.label ?? 'Custom backend',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
