import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = 'Version ${info.version} (${info.buildNumber})');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: AppStrings.appName),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.lg + FloatingAppBar.contentTopInset(context),
          AppSizes.lg,
          AppSizes.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSizes.xl),
            Center(
              child: Column(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/shopxy-icon.png',
                      width: 96,
                      height: 96,
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Text(
                    AppStrings.appName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    AppStrings.appBy,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    AppStrings.brandTagline,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.subtle,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: AppSizes.lg),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                        vertical: AppSizes.xs,
                      ),
                      child: Text(
                        _version ?? l10n.profileAppVersion,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.xxxl),

            _AboutLink(
              icon: AppIcons.shieldOutlined,
              label: l10n.profilePrivacyPolicy,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalPage.privacy()),
              ),
            ),
            const AppDivider.flush(),
            _AboutLink(
              icon: AppIcons.descriptionOutlined,
              label: l10n.profileTermsOfService,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalPage.terms()),
              ),
            ),

            const SizedBox(height: AppSizes.xxxl),
            Center(
              child: Text(
                AppStrings.copyright,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.subtle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({required this.icon, required this.label, required this.onTap});
  final AppIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Row(
          children: [
            AppIcon(icon, size: AppSizes.iconMd, color: AppColors.muted),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.black,
                ),
              ),
            ),
            AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}
