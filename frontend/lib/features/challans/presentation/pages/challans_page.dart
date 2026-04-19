import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/features/challans/presentation/pages/create_challan_page.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';

class ChallansPage extends StatefulWidget {
  const ChallansPage({super.key});

  @override
  State<ChallansPage> createState() => _ChallansPageState();
}

class _ChallansPageState extends State<ChallansPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChallansProvider>().loadChallans();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallansProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navChallans)),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: AppSearchBar(
              hint: AppStrings.searchChallans,
              onChanged: context.read<ChallansProvider>().setSearch,
            ),
          ),
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: [
                null,
                'PENDING',
                'CONVERTED',
                'CANCELLED',
              ]
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: AppSizes.sm),
                      child: FilterChip(
                        label: Text(s ?? AppStrings.all),
                        selected: provider.statusFilter == s,
                        onSelected: (_) => context.read<ChallansProvider>().setStatus(s),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          // List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.challans.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 56,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: AppSizes.md),
                            Text(
                              AppStrings.noChallans,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              AppStrings.challansTapCreate,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => context.read<ChallansProvider>().loadChallans(),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.sm,
                          ),
                          itemCount: provider.challans.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
                          itemBuilder: (ctx, i) {
                            final c = provider.challans[i];
                            return _ChallanTile(
                              challan: c,
                              onTap: () async {
                                final challansProvider = context.read<ChallansProvider>();
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChallanDetailPage(challanId: c.id),
                                  ),
                                );
                                if (changed == true && mounted) {
                                  challansProvider.loadChallans();
                                }
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final challansProvider = context.read<ChallansProvider>();
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateChallanPage()),
          );
          if (created == true && mounted) {
            challansProvider.loadChallans();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.createChallan),
      ),
    );
  }
}

class _ChallanTile extends StatelessWidget {
  const _ChallanTile({required this.challan, required this.onTap});
  final dynamic challan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');

    Color statusColor;
    switch (challan.status as String) {
      case 'CONVERTED':
        statusColor = const Color(0xFF1F8A5B);
      case 'CANCELLED':
        statusColor = theme.colorScheme.error;
      default:
        statusColor = theme.colorScheme.primary;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Icon(
            Icons.receipt_long_rounded,
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          challan.challanNo as String,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${challan.partyName} • ${df.format(challan.createdAt as DateTime)}'
          ' • ${challan.itemCount} ${AppStrings.items}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: _StatusBadge(status: challan.status as String),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case 'CONVERTED':
        color = const Color(0xFF1F8A5B);
      case 'CANCELLED':
        color = theme.colorScheme.error;
      default:
        color = theme.colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
