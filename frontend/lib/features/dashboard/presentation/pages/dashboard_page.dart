import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/stat_card.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardProvider>().loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DashboardProvider>();
    final stats = provider.stats;
    final currencyFormat = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => provider.loadStats(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: provider.isLoading && stats == null
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && stats == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppStrings.error),
                      const SizedBox(height: AppSizes.md),
                      ElevatedButton(
                        onPressed: () => provider.loadStats(),
                        child: const Text(AppStrings.retry),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadStats(),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    children: [
                      // Stats grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSizes.md,
                        crossAxisSpacing: AppSizes.md,
                        childAspectRatio: 1.4,
                        children: [
                          StatCard(
                            title: AppStrings.totalProducts,
                            value: '${stats?.totalProducts ?? 0}',
                            icon: Icons.inventory_2_rounded,
                            iconColor: theme.colorScheme.primary,
                          ),
                          StatCard(
                            title: AppStrings.categories,
                            value: '${stats?.totalCategories ?? 0}',
                            icon: Icons.category_rounded,
                            iconColor: theme.colorScheme.tertiary,
                          ),
                          StatCard(
                            title: AppStrings.lowStock,
                            value: '${stats?.lowStockCount ?? 0}',
                            icon: Icons.warning_amber_rounded,
                            iconColor: const Color(0xFFF59E0B),
                          ),
                          StatCard(
                            title: AppStrings.outOfStock,
                            value: '${stats?.outOfStockCount ?? 0}',
                            icon: Icons.error_outline_rounded,
                            iconColor: theme.colorScheme.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.xxl),

                      // Stock value card
                      Container(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        decoration: ShapeDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withValues(alpha: 0.8),
                            ],
                          ),
                          shape: AppShapes.squircle(AppSizes.radiusLg),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.stockValue,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.xs),
                                  Text(
                                    currencyFormat
                                        .format(stats?.totalStockValue ?? 0),
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(AppSizes.md),
                              decoration: ShapeDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: AppShapes.squircle(AppSizes.radiusMd),
                              ),
                              child: Icon(
                                Icons.account_balance_wallet_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: AppSizes.iconXl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.xxl),

                      // Recent activity
                      Text(
                        AppStrings.recentActivity,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSizes.md),
                      if (stats != null &&
                          stats.recentTransactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSizes.xxl),
                          child: Center(
                            child: Text(
                              AppStrings.noData,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else
                        ...?(stats?.recentTransactions
                            .map((t) => _TransactionTile(transaction: t))
                            .toList()),
                    ],
                  ),
                ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});
  final StockTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = transaction.isStockIn;
    final isOut = transaction.isStockOut;
    final color = isIn
        ? const Color(0xFF1F8A5B)
        : isOut
            ? theme.colorScheme.error
            : theme.colorScheme.tertiary;
    final icon = isIn
        ? Icons.arrow_downward_rounded
        : isOut
            ? Icons.arrow_upward_rounded
            : Icons.swap_vert_rounded;
    final timeFormat = DateFormat('dd MMM, hh:mm a');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: theme.cardTheme.color,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: ShapeDecoration(
                color: color.withValues(alpha: 0.1),
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              child: Icon(icon, size: AppSizes.iconMd, color: color),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.productName ?? 'Product #${transaction.productId}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    timeFormat.format(transaction.createdAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isOut ? "-" : "+"}${transaction.quantity.toStringAsFixed(transaction.quantity.truncateToDouble() == transaction.quantity ? 0 : 2)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
