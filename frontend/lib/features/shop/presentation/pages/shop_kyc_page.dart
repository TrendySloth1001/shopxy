import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// KYC scaffold — UI shell only. Lists the documents the verification
/// flow will collect; each row shows its current status (always
/// "Not uploaded" until the backend ships) and an Upload button
/// that's intentionally disabled. Built so the surface exists on
/// day one of the KYC service.
class ShopKycPage extends StatelessWidget {
  const ShopKycPage({super.key});

  @override
  Widget build(BuildContext context) {
    final docs = const [
      _KycDoc(
        title: 'PAN card',
        subtitle: 'Owner or business PAN. Required for payouts.',
        icon: Icons.badge_outlined,
      ),
      _KycDoc(
        title: 'GSTIN certificate',
        subtitle:
            'If your shop has a GSTIN, upload the registration certificate.',
        icon: Icons.receipt_long_outlined,
      ),
      _KycDoc(
        title: 'Cancelled cheque',
        subtitle:
            'Bank-issued cheque with account holder name visible. '
            'Confirms settlement-account ownership.',
        icon: Icons.account_balance_wallet_outlined,
      ),
      _KycDoc(
        title: 'Aadhaar / address proof',
        subtitle:
            'For sole-proprietor shops. Skip if you already have GSTIN '
            'on file.',
        icon: Icons.home_outlined,
      ),
      _KycDoc(
        title: 'Shop / business photo',
        subtitle:
            'Optional. Front-of-store photo helps trust + verification '
            'reviews.',
        icon: Icons.storefront_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('KYC documents')),
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
                      'Document uploads launch alongside the verified-seller '
                      'badge. Until then, this page lists the documents '
                      'you\'ll be asked for so you can prepare them ahead '
                      'of time.',
                      style:
                          TextStyle(color: AppColors.info, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          for (final d in docs) ...[
            Material(
              color: AppColors.white,
              shape: AppShapes.squircle(AppSizes.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.heroPanel,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(d.icon,
                          color: AppColors.brandStrong, size: 20),
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
                                  d.title,
                                  style: const TextStyle(
                                    color: AppColors.black,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const AppStatusBadge(
                                label: 'Not uploaded',
                                tone: AppStatusTone.warning,
                                weight: AppStatusWeight.soft,
                                dense: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            d.subtitle,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.upload_file_rounded,
                                size: 16),
                            label: const Text('Upload (coming soon)'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
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
