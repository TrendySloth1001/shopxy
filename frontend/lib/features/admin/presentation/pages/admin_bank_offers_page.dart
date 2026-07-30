import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/admin/data/models/platform_bank_offer.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_bank_offer_editor_sheet.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_bank_offers_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

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
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminBankOffersProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminBankOfferDeactivateTitle),
        content: Text(l10n.adminBankOfferDeactivateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.adminCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.adminDeactivate),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AdminBankOffersProvider>().deactivate(o.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AdminBankOffersProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.adminBankOffersTitle,
        actions: [
          IconButton(
            tooltip: l10n.adminRefresh,
            icon: const AppIcon(AppIcons.refresh),
            onPressed: provider.isLoading ? null : provider.load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const AppIcon(AppIcons.add),
        label: Text(l10n.adminBankOfferNew),
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
                controller: _scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.sm + FloatingAppBar.contentTopInset(context),
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
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm + FloatingAppBar.contentTopInset(context),
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
          color: AppColors.surface,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(color: AppColors.hairline, width: 1),
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final discount = offer.discountType == 'PERCENT'
        ? l10n.adminBankOfferPercentOff(offer.discountValue.toStringAsFixed(0))
        : l10n.adminBankOfferAmountOff(
            currencyFormat.format(offer.discountValue),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.surface,
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
                        style: theme.textTheme.bodyLarge?.extraBold,
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
                  '${offer.cardType} · '
                  '${l10n.adminBankOfferMinOrder(currencyFormat.format(offer.minOrderAmount))}'
                  '${offer.maxDiscount != null ? ' · ${l10n.adminBankOfferCap(currencyFormat.format(offer.maxDiscount))}' : ''}',
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
                  l10n.adminBankOfferValidRange(
                    dateFormat.format(offer.validFrom),
                    dateFormat.format(offer.validUntil),
                  ),
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
                      icon: const AppIcon(
                        AppIcons.powerSettingsNew,
                        size: AppSizes.iconSm,
                      ),
                      label: Text(l10n.adminDeactivate),
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
    return SafeArea(
      top: true,
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.accountBalanceOutlined,
                size: AppSizes.iconHuge,
                color: AppColors.subtle,
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                AppLocalizations.of(context).adminBankOffersEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          ),
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
    return SafeArea(
      top: true,
      bottom: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: AppSizes.md),
              FilledButton(
                onPressed: () => onRetry(),
                child: Text(AppLocalizations.of(context).adminRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
