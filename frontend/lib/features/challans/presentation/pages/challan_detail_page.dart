import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/data/datasources/challans_remote_data_source.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

class ChallanDetailPage extends StatefulWidget {
  const ChallanDetailPage({super.key, required this.challanId});
  final int challanId;

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
    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppStrings.cancelChallan,
      message: AppStrings.cancelChallanConfirm,
      confirmLabel: AppStrings.yes,
      cancelLabel: AppStrings.no,
      danger: true,
    );
    if (!confirmed || !mounted) return;

    final provider = context.read<ChallansProvider>();
    try {
      await provider.cancelChallan(widget.challanId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _convertToInvoice() async {
    setState(() => _isConverting = true);
    final provider = context.read<ChallansProvider>();
    try {
      final invoice = await provider.convertToInvoice(widget.challanId);
      if (!mounted) return;
      final invoiceId = invoice['id'] as int;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoiceId: invoiceId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_challan == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text(AppStrings.error)),
      );
    }

    final c = _challan!;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(c.challanNo),
        actions: [
          if (c.isPending)
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text(AppStrings.cancelChallan),
                ),
              ],
              onSelected: (v) {
                if (v == 'cancel') _cancel();
              },
            ),
        ],
      ),
      body: ListView(
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
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                  df.format(c.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.md),
                _InfoRow(label: AppStrings.partyName, value: c.partyName),
                if (c.partyPhone != null)
                  _InfoRow(label: AppStrings.phone, value: c.partyPhone!),
                if (c.note != null && c.note!.isNotEmpty)
                  _InfoRow(label: AppStrings.note, value: c.note!),
                if (c.isConverted && c.invoice != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  _InfoRow(
                    label: AppStrings.challanLinkedInvoice,
                    value: c.invoice!.invoiceNo,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          AppSectionHeader(
            title: AppStrings.challanItems.toUpperCase(),
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: c.items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSizes.lg),
                    child: Text(AppStrings.challanEmptyItems),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.items[i].productName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      c.items[i].productSku,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSizes.md),
                              Text(
                                '${c.items[i].quantity % 1 == 0 ? c.items[i].quantity.toInt() : c.items[i].quantity} ${c.items[i].unit}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
      bottomNavigationBar: c.isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: AppButton.primary(
                  label: AppStrings.convertToInvoice,
                  icon: Icons.receipt_long_rounded,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
