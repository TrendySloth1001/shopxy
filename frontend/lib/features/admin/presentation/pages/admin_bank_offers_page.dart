import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/admin/data/models/platform_bank_offer.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_bank_offer_editor_sheet.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_bank_offers_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Admin-only page (drawer entry gated by `User.isPlatformAdmin`). One
/// list of all platform bank offers regardless of status — admin
/// needs to see Off / Expired rows to bring them back. Tapping a row
/// opens the editor sheet; the FAB opens it in create mode.
class AdminBankOffersPage extends StatefulWidget {
  const AdminBankOffersPage({super.key});

  @override
  State<AdminBankOffersPage> createState() => _AdminBankOffersPageState();
}

class _AdminBankOffersPageState extends State<AdminBankOffersPage> {
  static final _date = DateFormat('d MMM y');
  static final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminBankOffersProvider>().load();
    });
  }

  Future<void> _openEditor({AdminPlatformBankOffer? existing}) async {
    final saved = await AdminBankOfferEditorSheet.show(
      context,
      existing: existing,
    );
    if (saved == true && mounted) {
      await context.read<AdminBankOffersProvider>().load();
    }
  }

  Future<void> _deactivate(AdminPlatformBankOffer o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate offer?'),
        content: Text(
          'Customers won\'t see this offer on any PDP. You can re-activate '
          'it later from this page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AdminBankOffersProvider>().deactivate(o.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminBankOffersProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Bank offers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : provider.load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New offer'),
      ),
      body: provider.isLoading && provider.offers.isEmpty
          ? const _OfferListSkeleton()
          : provider.error != null && provider.offers.isEmpty
              ? _ErrorBlock(message: provider.error!, onRetry: provider.load)
              : provider.offers.isEmpty
                  ? const _EmptyBlock()
                  : RefreshIndicator(
                      onRefresh: provider.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.sm,
                          AppSizes.lg,
                          AppSizes.fabClearance,
                        ),
                        itemCount: provider.offers.length,
                        itemBuilder: (_, i) {
                          final o = provider.offers[i];
                          return _OfferRow(
                            offer: o,
                            onEdit: () => _openEditor(existing: o),
                            onDeactivate: () => _deactivate(o),
                            dateFormat: _date,
                            currencyFormat: _currency,
                          );
                        },
                      ),
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets — shown while isLoading && offers.isEmpty
// ---------------------------------------------------------------------------

class _OfferListSkeleton extends StatelessWidget {
  const _OfferListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.fabClearance,
      ),
      itemCount: 4,
      itemBuilder: (_, _) => const _OfferRowSkeleton(),
    );
  }
}

class _OfferRowSkeleton extends StatelessWidget {
  const _OfferRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline, width: 1),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: bank · discount (bold) + status chip placeholder
              Row(
                children: [
                  const Expanded(
                    child: AppShimmerLine(widthFactor: 0.6, height: 16),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  AppShimmerBox(
                    width: 64,
                    height: 22,
                    radius: AppSizes.radiusSm,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              // Row 2: card-type · min-order
              const AppShimmerLine(widthFactor: 0.75, height: 13),
              const SizedBox(height: AppSizes.xs),
              // Row 3: optional terms (slightly shorter)
              const AppShimmerLine(widthFactor: 0.9, height: 12),
              const SizedBox(height: AppSizes.xs),
              // Row 4: valid date range
              const AppShimmerLine(widthFactor: 0.5, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.onEdit,
    required this.onDeactivate,
    required this.dateFormat,
    required this.currencyFormat,
  });
  final AdminPlatformBankOffer offer;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;

  AppStatusTone get _tone {
    if (!offer.isActive) return AppStatusTone.error;
    if (offer.isExpired) return AppStatusTone.warning;
    if (offer.isScheduled) return AppStatusTone.info;
    return AppStatusTone.success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = offer.discountType == 'PERCENT'
        ? '${offer.discountValue.toStringAsFixed(0)}% off'
        : '${currencyFormat.format(offer.discountValue)} off';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${offer.bank} · $discount',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AppStatusBadge(
                      label: offer.statusLabel,
                      tone: _tone,
                      weight: AppStatusWeight.soft,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '${offer.cardType} · min order '
                  '${currencyFormat.format(offer.minOrderAmount)}'
                  '${offer.maxDiscount != null ? ' · cap ${currencyFormat.format(offer.maxDiscount)}' : ''}',
                  style: theme.textTheme.bodyMedium,
                ),
                if (offer.terms != null && offer.terms!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    offer.terms!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSizes.xs),
                Text(
                  'Valid ${dateFormat.format(offer.validFrom)} – '
                  '${dateFormat.format(offer.validUntil)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                if (offer.isActive) ...[
                  const SizedBox(height: AppSizes.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onDeactivate,
                      icon: const Icon(Icons.power_settings_new,
                          size: AppSizes.iconSm),
                      label: const Text('Deactivate'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.account_balance_outlined,
                size: AppSizes.iconHuge, color: AppColors.subtle),
            SizedBox(height: AppSizes.md),
            Text(
              'No bank offers yet. Tap "New offer" to curate the first one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            FilledButton(
              onPressed: () => onRetry(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
