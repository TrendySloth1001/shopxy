import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/services/quotation_share.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

/// Full quotation detail for the customer: line items, totals, status timeline
/// and Accept / Decline. Accepting turns it into a confirmed invoice.
class ShopQuotationDetailPage extends StatefulWidget {
  const ShopQuotationDetailPage({
    super.key,
    required this.shop,
    required this.quotation,
  });
  final LinkedShop shop;
  final ShopQuotation quotation;

  @override
  State<ShopQuotationDetailPage> createState() =>
      _ShopQuotationDetailPageState();
}

class _ShopQuotationDetailPageState extends State<ShopQuotationDetailPage> {
  final NumberFormat _currency = AppFormat.inr;
  final _dateFmt = DateFormat('d MMM yyyy, h:mm a');
  bool _busy = false;
  bool _sharing = false;

  /// Re-read the live copy from the provider cache so status/invoice update
  /// in place after Accept/Decline without leaving the page.
  ShopQuotation get _q {
    final list = context.read<ShopsProvider>().quotationsFor(widget.shop);
    return list?.firstWhere(
          (x) => x.id == widget.quotation.id,
          orElse: () => widget.quotation,
        ) ??
        widget.quotation;
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<ShopsProvider>().acceptQuotation(
        widget.shop,
        widget.quotation.id,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackbar(
        context,
        message: 'Accepted — added to your invoices.',
        tone: AppSnackbarTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _decline() async {
    final provider = context.read<ShopsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline quotation'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Shown to the shop',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      await provider.declineQuotation(
        widget.shop,
        widget.quotation.id,
        declineNote: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Quotation declined')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _sharePdf() async {
    final provider = context.read<ShopsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final bytes = await provider.downloadQuotationPdf(
        widget.shop,
        widget.quotation.id,
      );
      if (!mounted) return;
      await shareQuotationPdf(
        context: context,
        quotationNo: _q.quotationNo,
        bytes: bytes,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _cancel() async {
    final provider = context.read<ShopsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw request?'),
        content: const Text('The shop will no longer see this quote request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await provider.cancelQuotation(widget.shop, widget.quotation.id);
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Quote request withdrawn')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  (Color, Color, String) _statusStyle(String status) {
    switch (status) {
      case 'REQUESTED':
        return (AppColors.brand, AppColors.brandSoft, 'Awaiting shop pricing');
      case 'PENDING':
        return (
          AppColors.warning,
          AppColors.warningSoft,
          'Awaiting your response',
        );
      case 'ACCEPTED':
        return (AppColors.success, AppColors.successSoft, 'Accepted');
      case 'DECLINED':
        return (AppColors.error, AppColors.errorSoft, 'Declined');
      case 'CANCELLED':
        return (AppColors.muted, AppColors.hairline, 'Withdrawn by shop');
      default:
        return (AppColors.muted, AppColors.hairline, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ShopsProvider>(); // rebuild on accept/decline
    final theme = Theme.of(context);
    final q = _q;
    final (fg, _, statusLabel) = _statusStyle(q.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(q.quotationNo),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.sm),
            child: ActionChip(
              onPressed: _sharing ? null : _sharePdf,
              tooltip: 'Download or share this quote as PDF',
              backgroundColor: AppColors.brandSoft,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: _sharing
                  ? const SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppIcon(
                      AppIcons.shareRounded,
                      size: AppSizes.iconSm,
                      color: AppColors.brand,
                    ),
              label: Text(
                'Share',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          // Status + dates — flat, no box.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSizes.xxs),
              Text(
                '${q.isRequested ? 'Requested' : 'Sent'} ${_dateFmt.format(q.createdAt.toLocal())}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              if (q.respondedAt != null)
                Text(
                  'Responded ${_dateFmt.format(q.respondedAt!.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              if (q.invoiceNo != null) ...[
                const SizedBox(height: AppSizes.xs),
                Text(
                  'Invoice ${q.invoiceNo} added to your ledger',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (q.status == 'DECLINED' && q.declineNote != null) ...[
                const SizedBox(height: AppSizes.xs),
                Text(
                  'Reason: ${q.declineNote}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.lg),

          // Items.
          _Label('Items (${q.items.length})'),
          const SizedBox(height: AppSizes.xs),
          for (int i = 0; i < q.items.length; i++) ...[
            if (i > 0) const AppDivider.flush(),
            _ItemRow(line: q.items[i], currency: _currency),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: AppDivider.flush(),
          ),

          // Totals.
          _totalRow('Subtotal', _currency.format(q.subtotal), theme),
          _totalRow('GST', _currency.format(q.taxAmount), theme),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: AppDivider.flush(),
          ),
          _totalRow('Total', _currency.format(q.total), theme, bold: true),

          if (q.note != null && q.note!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.lg),
            _Label(q.isRequested ? 'Your note' : 'Note from shop'),
            const SizedBox(height: AppSizes.xs),
            Text(q.note!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
      bottomNavigationBar: q.isRequested
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.lg,
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: AppSizes.iconMd,
                            height: AppSizes.iconMd,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Withdraw request',
                            style: theme.textTheme.bodyMedium?.extraBold,
                          ),
                  ),
                ),
              ),
            )
          : q.isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _decline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.lg,
                          ),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _busy ? null : _accept,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSizes.lg,
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: AppSizes.iconMd,
                                height: AppSizes.iconMd,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : Text(
                                'Accept · ${_currency.format(q.total)}',
                                style: theme.textTheme.bodyMedium?.extraBold,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _totalRow(
    String label,
    String value,
    ThemeData theme, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: bold ? null : AppColors.muted,
              fontWeight: bold ? FontWeight.w800 : null,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line, required this.currency});
  final ShopQuotationLine line;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyStr = line.quantity == line.quantity.roundToDouble()
        ? line.quantity.toStringAsFixed(0)
        : line.quantity.toStringAsFixed(2);
    final raw = line.imageUrl ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Row(
        children: [
          if (raw.isEmpty)
            Container(
              width: AppSizes.avatarSm,
              height: AppSizes.avatarSm,
              decoration: ShapeDecoration(
                color: AppColors.brandSoft,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: const AppIcon(
                AppIcons.inventory2Outlined,
                size: AppSizes.iconMd,
                color: AppColors.brand,
              ),
            )
          else
            ClipPath(
              clipper: ShapeBorderClipper(
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              child: NetworkImageBox(
                url: resolveImageUrl(raw),
                width: AppSizes.avatarSm,
                height: AppSizes.avatarSm,
                placeholderColor: AppColors.brandSoft,
              ),
            ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: theme.textTheme.bodyLarge?.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  '$qtyStr × ${currency.format(line.unitPrice)}'
                  '${line.taxPercent > 0 ? ' · ${line.taxPercent.toStringAsFixed(0)}% GST' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            currency.format(line.lineTotal),
            style: theme.textTheme.bodyLarge?.bold,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label);
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
