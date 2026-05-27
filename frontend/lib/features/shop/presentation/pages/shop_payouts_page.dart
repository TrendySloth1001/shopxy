import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Payouts scaffold — UI shell only, no backend wiring. Surfaces
/// the structured fields a real Razorpay / Cashfree integration
/// will need so the visual surface lands ahead of the wire. The
/// "Save" button stays disabled until the gateway is connected;
/// this page is purely so merchants can see what's coming.
class ShopPayoutsPage extends StatefulWidget {
  const ShopPayoutsPage({super.key});

  @override
  State<ShopPayoutsPage> createState() => _ShopPayoutsPageState();
}

class _ShopPayoutsPageState extends State<ShopPayoutsPage> {
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();
  final _upi = TextEditingController();
  String _payoutFrequency = 'WEEKLY';

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    _ifsc.dispose();
    _upi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Payouts & settlement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.huge),
        children: [
          const _ComingSoonBanner(
            message:
                'Payouts go live when the payment gateway lands. '
                'Wire-up needs Razorpay / Cashfree credentials and '
                'KYC. Fields below are previews so you can see the '
                'shape of what will be asked.',
          ),
          const SizedBox(height: AppSizes.lg),
          _SectionTitle(label: 'Settlement account'),
          const SizedBox(height: AppSizes.sm),
          _Card(
            child: Column(
              children: [
                TextField(
                  controller: _holder,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Account holder name',
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _account,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Bank account number',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _ifsc,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'IFSC'),
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: _upi,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'UPI VPA (alternative)',
                    hintText: 'shop@upi',
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                DropdownButtonFormField<String>(
                  initialValue: _payoutFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Payout frequency',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                    DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                    DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                  ],
                  onChanged: null,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          _SectionTitle(label: 'Payout history'),
          const SizedBox(height: AppSizes.sm),
          _Card(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 40, color: AppColors.muted),
                    SizedBox(height: AppSizes.sm),
                    Text(
                      'No payouts yet',
                      style: TextStyle(
                          color: AppColors.muted, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Payouts will land here once the gateway is live.",
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            ),
            child: const Text('Save (disabled until gateway is live)'),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBanner extends StatelessWidget {
  const _ComingSoonBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.infoSoft,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.info),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(color: AppColors.info, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: Padding(padding: const EdgeInsets.all(AppSizes.md), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      );
}
