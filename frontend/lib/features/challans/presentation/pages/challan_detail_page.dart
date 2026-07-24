import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/data/datasources/challans_remote_data_source.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class ChallanDetailPage extends StatefulWidget {
  const ChallanDetailPage({super.key, required this.challanId});
  final String challanId;

  @override
  State<ChallanDetailPage> createState() => _ChallanDetailPageState();
}

class _ChallanDetailPageState extends State<ChallanDetailPage> {
  Challan? _challan;
  bool _isLoading = true;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ds = context.read<ChallansRemoteDataSource>();
      final challan = await ds.getChallanById(widget.challanId);
      if (mounted) {
        setState(() {
          _challan = challan;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.challansCancel,
      message: l10n.challansCancelConfirm,
      confirmLabel: l10n.challansYes,
      cancelLabel: l10n.challansNo,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<ChallansProvider>();
    try {
      await provider.cancelChallan(widget.challanId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _convertToInvoice() async {
    setState(() => _isConverting = true);
    final provider = context.read<ChallansProvider>();
    try {
      final invoice = await provider.convertToInvoice(widget.challanId);
      if (!mounted) return;
      final invoiceId = invoice['id'].toString();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: invoiceId),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const _ChallanDetailSkeleton();
    }
    if (_challan == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Center(child: Text(l10n.challansError)),
        ),
      );
    }

    final c = _challan!;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: c.challanNo,
        actions: [
          if (c.isPending)
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'cancel',
                  child: Text(l10n.challansCancel),
                ),
              ],
              onSelected: (v) {
                if (v == 'cancel') _cancel();
              },
            ),
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            GlassHero.line(
              kind: LineArt.deliveryNote,
              height: AppSizes.heroHeightMd,
              illustrationSize: AppSizes.productImageSize,
              accent: c.isConverted
                  ? AppColors.brand
                  : (c.isCancelled ? AppColors.error : AppColors.brand),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.challanNo,
                                style: theme.textTheme.headlineSmall?.bold,
                              ),
                            ),
                            AppStatusBadge(
                              label: c.status,
                              tone: challanStatusTone(c.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          df.format(c.createdAt.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: AppSizes.md),
                        _InfoRow(
                          label: l10n.challansPartyName,
                          value: c.partyName,
                        ),
                        if (c.partyPhone != null)
                          _InfoRow(
                            label: l10n.challansPhone,
                            value: c.partyPhone!,
                          ),
                        if (c.note != null && c.note!.isNotEmpty)
                          _InfoRow(label: l10n.challansNote, value: c.note!),
                        if (c.isConverted && c.invoice != null) ...[
                          const SizedBox(height: AppSizes.sm),
                          _InfoRow(
                            label: l10n.challansLinkedInvoice,
                            value: c.invoice!.invoiceNo,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  AppSectionHeader(
                    title: l10n.challansItemsHeader.toUpperCase(),
                    padding: const EdgeInsets.only(bottom: AppSizes.sm),
                  ),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: c.items.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(AppSizes.lg),
                            child: Text(l10n.challansEmptyItems),
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < c.items.length; i++) ...[
                                if (i > 0) const AppDivider.flush(),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSizes.lg,
                                    vertical: AppSizes.md,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.items[i].productName,
                                              style: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.medium,
                                            ),
                                            Text(
                                              c.items[i].productSku,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.muted,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSizes.md),
                                      Text(
                                        '${c.items[i].quantity % 1 == 0 ? c.items[i].quantity.toInt() : c.items[i].quantity} ${c.items[i].unit}',
                                        style: theme
                                            .textTheme
                                            .bodyMedium
                                            ?.semibold,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSizes.huge),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: c.isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: AppButton.primary(
                  label: l10n.challansConvertToInvoice,
                  icon: AppIcons.receiptLongRounded,
                  onPressed: _convertToInvoice,
                  isLoading: _isConverting,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                ),
              ),
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton shown while challan detail is loading
// ---------------------------------------------------------------------------

class _ChallanDetailSkeleton extends StatelessWidget {
  const _ChallanDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        titleWidget: AppShimmerLine(widthFactor: 0.4, height: AppSizes.iconSm),
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            // Mirror of GlassHero.line
            AppShimmerBox(
              width: double.infinity,
              height: AppSizes.heroHeightMd,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
                  // Info card
                  AppCard(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Challan number / status row
                        Row(
                          children: [
                            const Expanded(
                              child: AppShimmerLine(
                                widthFactor: 0.6,
                                height: 20,
                              ),
                            ),
                            const SizedBox(width: AppSizes.md),
                            AppShimmerBox(
                              width: 72,
                              height: AppSizes.iconSm,
                              radius: AppSizes.radiusFull,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.xs),
                        // Date line
                        const AppShimmerLine(widthFactor: 0.45, height: 13),
                        const SizedBox(height: AppSizes.md),
                        // _InfoRow placeholders: party name, phone, note
                        const AppShimmerLine(widthFactor: 0.75, height: 13),
                        const SizedBox(height: AppSizes.xs),
                        const AppShimmerLine(widthFactor: 0.5, height: 13),
                        const SizedBox(height: AppSizes.xs),
                        const AppShimmerLine(widthFactor: 0.85, height: 13),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  // Section header placeholder
                  const AppShimmerLine(widthFactor: 0.35, height: 13),
                  const SizedBox(height: AppSizes.sm),
                  // Items card
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: List.generate(3, (i) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.md,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    AppShimmerLine(
                                      widthFactor: 0.65,
                                      height: 14,
                                    ),
                                    SizedBox(height: AppSizes.xs),
                                    AppShimmerLine(
                                      widthFactor: 0.4,
                                      height: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSizes.md),
                              AppShimmerBox(
                                width: 48,
                                height: 14,
                                radius: AppSizes.radiusSm,
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: AppSizes.huge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xs),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          Text(value, style: theme.textTheme.bodySmall?.medium),
        ],
      ),
    );
  }
}
