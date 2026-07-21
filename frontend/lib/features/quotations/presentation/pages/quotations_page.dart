import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/pages/create_quotation_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotation_detail_page.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Merchant list of quotations sent to customers. Clean divided rows; tap opens
/// the detail page. FAB opens the catalogue → bucket → send flow.
class QuotationsPage extends StatefulWidget {
  const QuotationsPage({super.key});

  @override
  State<QuotationsPage> createState() => _QuotationsPageState();
}

class _QuotationsPageState extends State<QuotationsPage> {
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
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
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: 'Quotations'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const AppIcon(AppIcons.addRounded),
        label: const Text('New quotation'),
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: p.isLoading && p.items.isEmpty
            ? const _QuotationsSkeleton()
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
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => p.load(),
                child: p.items.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: AppSizes.productImageSize),
                          AppIcon(
                            AppIcons.requestQuoteOutlined,
                            size: AppSizes.iconHuge,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: AppSizes.md),
                          Center(
                            child: Text(
                              'No quotations yet.\nTap “New quotation” to build one.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.lg,
                          AppSizes.sm,
                          AppSizes.lg,
                          AppSizes.sm,
                        ),
                        itemCount: p.items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSizes.sm),
                        itemBuilder: (_, i) => _QuotationRow(
                          q: p.items[i],
                          currency: _currency,
                          dateFmt: _dateFmt,
                          onTap: () {
                            final prov = context.read<QuotationsProvider>();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuotationDetailPage(quotation: p.items[i]),
                              ),
                            ).then((_) => prov.load());
                          },
                        ),
                      ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading state — mirrors _QuotationRow layout
// ---------------------------------------------------------------------------

class _QuotationsSkeleton extends StatelessWidget {
  const _QuotationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (_, _) => const _QuotationRowSkeleton(),
    );
  }
}

class _QuotationRowSkeleton extends StatelessWidget {
  const _QuotationRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          // Expanded left column — mirrors _QuotationRow's Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: title shimmer + badge shimmer
                Row(
                  children: [
                    AppShimmerLine(widthFactor: 0.35, height: 16),
                    const SizedBox(width: AppSizes.sm),
                    AppShimmerBox(
                      width: 72,
                      height: 20,
                      radius: AppSizes.radiusXl,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                // Subtitle line
                AppShimmerLine(widthFactor: 0.6, height: 12),
              ],
            ),
          ),
          // Right side: price amount
          AppShimmerLine(widthFactor: 0.15, height: 16),
          const SizedBox(width: AppSizes.xs),
          // Chevron placeholder
          const SizedBox(width: AppSizes.iconSm),
        ],
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
    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                    Row(
                      children: [
                        Text(
                          q.quotationNo,
                          style: theme.textTheme.titleMedium?.bold,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.sm,
                            vertical: AppSizes.xs,
                          ),
                          decoration: ShapeDecoration(
                            color: bg,
                            shape: AppShapes.squircle(AppSizes.radiusXl),
                          ),
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      '${q.partyName} · ${dateFmt.format(q.createdAt)} · ${q.items.length} item${q.items.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                currency.format(q.total),
                style: theme.textTheme.titleMedium?.extraBold,
              ),
              const SizedBox(width: AppSizes.xs),
              AppIcon(AppIcons.chevronRightRounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
