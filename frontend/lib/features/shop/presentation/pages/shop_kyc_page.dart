import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// KYC scaffold — UI shell only. Lists the documents the verification flow will
/// collect; each row shows its status (always "Not uploaded" until the backend
/// ships) and a disabled Upload affordance. Editorial layout: a flat intro and
/// hairline-divided rows, no cards — matching Shop operations and Payouts.
///
/// Note: the identity/bank verification that actually enables payouts happens in
/// the Payouts onboarding (Razorpay Route). This page is the future
/// document-upload surface for the verified-seller badge.
class ShopKycPage extends StatelessWidget {
  const ShopKycPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final docs = [
      _KycDoc(
        title: l10n.shopKycPanTitle,
        subtitle: l10n.shopKycPanSubtitle,
        icon: Icons.badge_outlined,
      ),
      _KycDoc(
        title: l10n.shopKycGstinTitle,
        subtitle: l10n.shopKycGstinSubtitle,
        icon: Icons.receipt_long_outlined,
      ),
      _KycDoc(
        title: l10n.shopKycChequeTitle,
        subtitle: l10n.shopKycChequeSubtitle,
        icon: Icons.account_balance_wallet_outlined,
      ),
      _KycDoc(
        title: l10n.shopKycAadhaarTitle,
        subtitle: l10n.shopKycAadhaarSubtitle,
        icon: Icons.home_outlined,
      ),
      _KycDoc(
        title: l10n.shopKycPhotoTitle,
        subtitle: l10n.shopKycPhotoSubtitle,
        icon: Icons.storefront_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(l10n.shopKycTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.huge),
        children: [
          // Flat intro — no card.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: AppSizes.iconMd),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    l10n.shopKycIntro,
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          for (final d in docs) _KycRow(doc: d),
        ],
      ),
    );
  }
}

class _KycRow extends StatelessWidget {
  const _KycRow({required this.doc});
  final _KycDoc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            decoration: BoxDecoration(
              color: AppColors.heroPanel,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(doc.icon, color: AppColors.brandStrong, size: AppSizes.iconMd),
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
                        doc.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AppStatusBadge(
                      label: l10n.shopKycNotUploaded,
                      tone: AppStatusTone.warning,
                      weight: AppStatusWeight.soft,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  doc.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.sm),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.upload_file_rounded, size: AppSizes.iconSm),
                  label: Text(l10n.shopKycUploadComingSoon),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KycDoc {
  const _KycDoc({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;
}
