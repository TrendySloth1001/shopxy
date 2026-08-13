import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/pages/create_quotation_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotation_detail_page.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
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
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<QuotationsProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
                        controller: _scrollCtrl,
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

  (AppStatusTone, String) _style() {
    switch (q.status) {
      case 'REQUESTED':
        return (AppStatusTone.info, 'New request');
      case 'PENDING':
        return (AppStatusTone.warning, 'Awaiting customer');
      case 'ACCEPTED':
        return (AppStatusTone.success, 'Accepted');
      case 'DECLINED':
        return (AppStatusTone.error, 'Declined');
      case 'CANCELLED':
        return (AppStatusTone.neutral, 'Cancelled');
      default:
        return (AppStatusTone.neutral, q.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (tone, label) = _style();
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
                        Flexible(
                          child: Text(
                            q.quotationNo,
                            style: theme.textTheme.titleSmall?.bold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        // Flexible: "Awaiting customer" next to a six-figure
                        // total left no room, and a fixed-width pill overflowed
                        // the row rather than giving way.
                        Flexible(
                          child: AppStatusBadge(
                            label: label,
                            tone: tone,
                            weight: AppStatusWeight.soft,
                            dense: true,
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
              const SizedBox(width: AppSizes.md),
              Text(
                currency.format(q.total),
                style: theme.textTheme.titleSmall?.bold,
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
