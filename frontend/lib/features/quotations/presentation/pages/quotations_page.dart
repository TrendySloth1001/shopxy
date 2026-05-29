import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/pages/create_quotation_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotation_detail_page.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// Merchant list of quotations sent to customers. Clean divided rows; tap opens
/// the detail page. FAB opens the catalogue → bucket → send flow.
class QuotationsPage extends StatefulWidget {
  const QuotationsPage({super.key});

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('d MMM y');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<QuotationsProvider>().load();
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateQuotationPage()),
    );
    if (created == true && mounted) {
      await context.read<QuotationsProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<QuotationsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Quotations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New quotation'),
      ),
      body: p.isLoading && p.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : p.error != null && p.items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSizes.md),
                        FilledButton(
                            onPressed: () => p.load(),
                            child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => p.load(),
                  child: p.items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.request_quote_outlined,
                                size: 44, color: AppColors.muted),
                            SizedBox(height: AppSizes.md),
                            Center(
                              child: Text(
                                'No quotations yet.\nTap “New quotation” to build one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.sm),
                          itemCount: p.items.length,
                          separatorBuilder: (_, _) => Container(
                              height: 1,
                              color: AppColors.hairline,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.lg)),
                          itemBuilder: (_, i) => _QuotationRow(
                            q: p.items[i],
                            currency: _currency,
                            dateFmt: _dateFmt,
                            onTap: () {
                              final prov = context.read<QuotationsProvider>();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuotationDetailPage(
                                      quotation: p.items[i]),
                                ),
                              ).then((_) => prov.load());
                            },
                          ),
                        ),
                ),
    );
  }
}

class _QuotationRow extends StatelessWidget {
  const _QuotationRow({
    required this.q,
    required this.currency,
    required this.dateFmt,
    required this.onTap,
  });
  final Quotation q;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  (Color, Color, String) _style() {
    switch (q.status) {
      case 'REQUESTED':
        return (AppColors.brand, AppColors.brandSoft, 'New request');
      case 'PENDING':
        return (AppColors.warning, AppColors.warningSoft, 'Awaiting customer');
      case 'ACCEPTED':
        return (AppColors.success, AppColors.successSoft, 'Accepted');
      case 'DECLINED':
        return (AppColors.error, AppColors.errorSoft, 'Declined');
      case 'CANCELLED':
        return (AppColors.muted, AppColors.heroPanel, 'Cancelled');
      default:
        return (AppColors.muted, AppColors.heroPanel, q.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fg, bg, label) = _style();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(q.quotationNo,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(width: AppSizes.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(label,
                            style: TextStyle(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${q.partyName} · ${dateFmt.format(q.createdAt)} · ${q.items.length} item(s)',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(currency.format(q.total),
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(width: AppSizes.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
