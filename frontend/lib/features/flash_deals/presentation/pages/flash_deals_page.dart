import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/analytics/presentation/pages/flash_deal_analytics_page.dart';
import 'package:shopxy/features/flash_deals/data/models/flash_deal.dart';
import 'package:shopxy/features/flash_deals/presentation/pages/flash_deal_editor_sheet.dart';
import 'package:shopxy/features/flash_deals/presentation/providers/flash_deals_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class FlashDealsPage extends StatefulWidget {
  const FlashDealsPage({super.key});

  @override
  State<FlashDealsPage> createState() => _FlashDealsPageState();
}

class _FlashDealsPageState extends State<FlashDealsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FlashDealsProvider>().load();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _openEditor({FlashDeal? existing}) async {
    final changed = await FlashDealEditorSheet.show(context, existing: existing);
    if (changed == true && mounted) {
      await context.read<FlashDealsProvider>().load();
    }
  }

  Future<void> _cancel(FlashDeal deal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel flash deal?'),
        content: Text(
          'Stops accepting new buyers at the discounted price. '
          'Already-claimed units stay claimed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep running'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningSoft,
              foregroundColor: AppColors.warning,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel sale'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<FlashDealsProvider>().cancel(deal.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FlashDealsProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Flash deals'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: 'Live (${provider.ofStatus(FlashDealStatus.active).length})'),
            Tab(text: 'Scheduled (${provider.ofStatus(FlashDealStatus.scheduled).length})'),
            Tab(text: 'Past (${provider.ofStatus(FlashDealStatus.past).length})'),
          ],
        ),
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
        icon: const Icon(Icons.bolt),
        label: const Text('New flash deal'),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _list(provider, FlashDealStatus.active),
          _list(provider, FlashDealStatus.scheduled),
          _list(provider, FlashDealStatus.past),
        ],
      ),
    );
  }

  Widget _list(FlashDealsProvider provider, FlashDealStatus status) {
    final deals = provider.ofStatus(status);
    if (provider.isLoading && deals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && deals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Text(provider.error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (deals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Text(
            switch (status) {
              FlashDealStatus.active => 'No live flash deals.\nTap “New flash deal” to start one.',
              FlashDealStatus.scheduled => 'Nothing scheduled.',
              FlashDealStatus.past => 'No past flash deals yet.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.lg, AppSizes.lg, 96),
        itemCount: deals.length,
        itemBuilder: (context, i) => _DealTile(
          deal: deals[i],
          status: status,
          onTap: () => _openEditor(existing: deals[i]),
          onCancel: () => _cancel(deals[i]),
        ),
      ),
    );
  }
}

class _DealTile extends StatelessWidget {
  const _DealTile({
    required this.deal,
    required this.status,
    required this.onTap,
    required this.onCancel,
  });
  final FlashDeal deal;
  final FlashDealStatus status;
  final VoidCallback onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final product = deal.product;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: ShapeDecoration(
                        color: AppColors.heroPanel,
                        shape: AppShapes.squircle(AppSizes.radiusSm),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: product?.imageUrl != null
                          ? Image.network(
                              resolveImageUrl(product!.imageUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.inventory_2_outlined, color: AppColors.muted),
                            )
                          : const Icon(Icons.inventory_2_outlined, color: AppColors.muted),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product?.name ?? 'Product #${deal.productId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '₹${deal.flashPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFE05A2A),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (product != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '₹${product.mrp.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.sm),
                                if (deal.discountPct > 0)
                                  Text(
                                    '${deal.discountPct}% off',
                                    style: const TextStyle(
                                      color: Color(0xFFE05A2A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Analytics',
                      icon: const Icon(Icons.bar_chart_outlined),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FlashDealAnalyticsPage(
                              flashSaleId: deal.id,
                            ),
                          ),
                        );
                      },
                    ),
                    if (status == FlashDealStatus.active ||
                        status == FlashDealStatus.scheduled)
                      IconButton(
                        tooltip: 'Cancel',
                        icon: const Icon(Icons.stop_circle_outlined),
                        onPressed: onCancel,
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                _SoldBar(soldPct: deal.soldPct, sold: deal.soldCount, limit: deal.stockLimit),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '${df.format(deal.startAt.toLocal())}  →  ${df.format(deal.endAt.toLocal())}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoldBar extends StatelessWidget {
  const _SoldBar({required this.soldPct, required this.sold, required this.limit});
  final double soldPct;
  final int sold;
  final int limit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3D2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            FractionallySizedBox(
              widthFactor: soldPct,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE05A2A),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$sold / $limit claimed  ·  ${(soldPct * 100).round()}%',
          style: const TextStyle(
            color: Color(0xFFE05A2A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
