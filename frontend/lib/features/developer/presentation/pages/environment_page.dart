import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/config/app_environment.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/main.dart' show bootstrapShopxy;
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// Developer-only backend switcher. Reachable from Settings, and only for the
/// account named in [kDeveloperEmail].
///
/// Strings here are intentionally not localised: the screen is gated to one
/// hardcoded developer address, so a Hindi translation of "Dev tunnel" would
/// be shipped weight nobody can ever read.
class EnvironmentPage extends StatefulWidget {
  const EnvironmentPage({super.key});

  @override
  State<EnvironmentPage> createState() => _EnvironmentPageState();
}

class _EnvironmentPageState extends State<EnvironmentPage> {
  bool _switching = false;

  Future<void> _select(AppEnvironment env) async {
    if (_switching) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Switch to ${env.label}?',
      message:
          'You will be signed out and the app will restart. '
          '${env.label} has its own database, so nothing from the current '
          'environment carries over.',
      confirmLabel: 'Switch',
    );
    if (!confirmed || !mounted) return;

    setState(() => _switching = true);
    final auth = context.read<AuthProvider>();
    // Sign out FIRST, while the old base URL is still in force — the refresh
    // token being revoked belongs to the environment we're leaving, and the
    // new one would reject it. This also fans out to every registered
    // provider, wiping the response cache and the offline outbox.
    try {
      await auth.logout();
    } catch (_) {
      // A failed server-side logout must not strand us mid-switch; the local
      // token clear inside logout() has already happened.
    }
    await AppEnvironments.select(env);
    // Rebuild the whole object graph against the new backend. This replaces
    // the root widget, so nothing below survives and this State is gone by
    // the time it returns — hence no setState afterwards.
    await bootstrapShopxy();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = AppEnvironments.matching(AppConfig.apiBaseUrl);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const FloatingAppBar(title: 'Environment'),
      body: AbsorbPointer(
        absorbing: _switching,
        child: ListView(
          padding: EdgeInsets.only(
            top: FloatingAppBar.contentTopInset(context),
            bottom: AppSizes.huge,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                0,
              ),
              child: _Callout(
                text: _switching
                    ? 'Signing out and restarting…'
                    : 'Each backend has its own database. Switching signs you '
                          'out and restarts the app so no data from the '
                          'current environment is left on screen.',
                busy: _switching,
              ),
            ),
            const AppSectionHeader(title: 'BACKEND'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < AppEnvironments.all.length; i++) ...[
                      if (i > 0) const AppDivider.flush(),
                      _EnvironmentRow(
                        environment: AppEnvironments.all[i],
                        selected: AppEnvironments.all[i].id == active?.id,
                        onTap: () => _select(AppEnvironments.all[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // When a dart-define points the build somewhere bespoke, no entry
            // matches — say so rather than silently showing nothing selected.
            if (active == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.lg,
                  0,
                ),
                child: Text(
                  'Currently pointed at ${AppConfig.apiBaseUrl}, which is not '
                  'one of the entries above (set via --dart-define).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({
    required this.environment,
    required this.selected,
    required this.onTap,
  });

  final AppEnvironment environment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: selected ? null : onTap,
      splashColor: AppColors.surfaceTint,
      highlightColor: AppColors.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    environment.label,
                    style: theme.textTheme.bodyLarge?.semibold,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    environment.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    environment.baseUrl,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.subtle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            if (selected)
              AppIcon(
                AppIcons.checkCircleRounded,
                color: AppColors.brandStrong,
                size: AppSizes.iconMd,
              )
            else
              AppIcon(AppIcons.chevronRightRounded, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.text, required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.tileBg(AppColors.infoSoft),
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const SizedBox(
              width: AppSizes.iconMd,
              height: AppSizes.iconMd,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            AppIcon(
              AppIcons.infoOutlineRounded,
              color: AppColors.info,
              size: AppSizes.iconMd,
            ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
