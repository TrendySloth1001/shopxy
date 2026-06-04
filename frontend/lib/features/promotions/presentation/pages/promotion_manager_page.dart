import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/promotions/data/models/promotion.dart';
import 'package:shopxy/features/promotions/presentation/providers/promotions_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Lists every promotion the merchant has set up and provides an entry
/// to the create sheet. Each tile shows a budget progress bar, a daily
/// cap bar, and a status chip — at a glance a merchant can tell which
/// campaigns are live, paused, or burning through cap fastest.
class PromotionManagerPage extends StatefulWidget {
  const PromotionManagerPage({super.key});

  @override
  State<PromotionManagerPage> createState() => _PromotionManagerPageState();
}

class _PromotionManagerPageState extends State<PromotionManagerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PromotionsProvider>().load();
    });
  }

  Future<void> _openCreate() async {
    final ok = await _CreatePromotionSheet.show(context);
    if (ok == true && mounted) {
      await context.read<PromotionsProvider>().load();
    }
  }

  Future<void> _confirmCancel(Promotion p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel promotion?'),
        content: Text('Stops spend on "${p.productName}". Cannot be resumed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep running'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel promo'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<PromotionsProvider>().cancel(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PromotionsProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Promotions'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : provider.load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('New promo'),
      ),
      body: provider.isLoading && provider.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.load,
              child: provider.items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: AppSizes.huge),
                        Center(
                          child: Text(
                            'No promotions yet — tap + to create one',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.lg,
                        AppSizes.lg,
                        AppSizes.lg,
                        AppSizes.massive,
                      ),
                      itemCount: provider.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
                      itemBuilder: (_, i) {
                        final p = provider.items[i];
                        return _PromoCard(
                          promotion: p,
                          onCancel: p.isActive ? () => _confirmCancel(p) : null,
                        );
                      },
                    ),
            ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promotion, this.onCancel});
  final Promotion promotion;
  final VoidCallback? onCancel;

  String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final now = DateTime.now();
    final status = promotion.statusLabel(now);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  promotion.productName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _StatusChip(label: status, active: promotion.isActive),
              if (onCancel != null)
                IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.stop_circle_outlined),
                  onPressed: onCancel,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            '${df.format(promotion.startAt)}  →  ${df.format(promotion.endAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          _Bar(
            label: 'Spend',
            value: _rupees(promotion.spendPaise),
            cap: _rupees(promotion.budgetPaise),
            pct: promotion.spendPctOfBudget,
            color: AppColors.brand,
          ),
          const SizedBox(height: AppSizes.sm),
          _Bar(
            label: "Today's spend",
            value: _rupees(promotion.spendTodayPaise),
            cap: _rupees(promotion.dailyCapPaise),
            pct: promotion.spendPctOfDailyCap,
            color: AppColors.accentIndigo,
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: AppSizes.iconSm,
                color: AppColors.muted,
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                '${promotion.deliveredImpressions} impressions @ ${_rupees(promotion.cpmPaise)}/1k',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.successSoft : AppColors.heroPanel;
    final fg = active ? AppColors.success : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.cap,
    required this.pct,
    required this.color,
  });
  final String label;
  final String value;
  final String cap;
  final double pct;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
            Text(
              '$value / $cap',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.xs),
        LinearProgressIndicator(
          value: pct,
          minHeight: AppSizes.sm,
          backgroundColor: AppColors.heroPanel,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }
}

class _CreatePromotionSheet extends StatefulWidget {
  const _CreatePromotionSheet();

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, _) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: const _CreatePromotionSheet(),
        ),
      ),
    );
  }

  @override
  State<_CreatePromotionSheet> createState() => _CreatePromotionSheetState();
}

class _CreatePromotionSheetState extends State<_CreatePromotionSheet> {
  Product? _product;
  final _searchController = TextEditingController();
  List<Product> _searchResults = [];
  bool _searching = false;
  final _budgetRupees = TextEditingController(text: '1000');
  final _dailyCapRupees = TextEditingController(text: '200');
  final _cpmRupees = TextEditingController(text: '10');
  DateTime? _startAt;
  DateTime? _endAt;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    _budgetRupees.dispose();
    _dailyCapRupees.dispose();
    _cpmRupees.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String q) async {
    if (q.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final ds = context.read<ProductsRemoteDataSource>();
    final result = await ds.getProducts(search: q, limit: 8);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _searchResults = result.products;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final t = time ?? const TimeOfDay(hour: 0, minute: 0);
    final combined = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  int? _toPaise(String rupees) {
    final n = double.tryParse(rupees);
    if (n == null || n <= 0) return null;
    return (n * 100).round();
  }

  /// Inline error shown directly under the daily-cap field. Returns
  /// non-null only when both budget and daily-cap parse successfully so
  /// half-typed values don't read as errors.
  String? get _dailyCapError {
    final budget = _toPaise(_budgetRupees.text);
    final cap = _toPaise(_dailyCapRupees.text);
    if (budget == null || cap == null) return null;
    if (cap > budget) return 'Cannot exceed total budget';
    return null;
  }

  Future<void> _submit() async {
    final product = _product;
    final budget = _toPaise(_budgetRupees.text);
    final dailyCap = _toPaise(_dailyCapRupees.text);
    final cpm = _toPaise(_cpmRupees.text);
    final messenger = ScaffoldMessenger.of(context);
    if (product == null || budget == null || dailyCap == null || cpm == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pick a product + numeric budget/cap/CPM')),
      );
      return;
    }
    if (dailyCap > budget) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Daily cap cannot exceed total budget')),
      );
      return;
    }
    if (_startAt == null || _endAt == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a start + end')));
      return;
    }
    if (!_endAt!.isAfter(_startAt!)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('End must be after start')),
      );
      return;
    }

    setState(() => _busy = true);
    final result = await context.read<PromotionsProvider>().create({
      'productId': product.id,
      'budgetPaise': budget,
      'dailyCapPaise': dailyCap,
      'cpmPaise': cpm,
      'startAt': _startAt!.toUtc().toIso8601String(),
      'endAt': _endAt!.toUtc().toIso8601String(),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<PromotionsProvider>().error ?? 'Create failed',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.xxxl,
          height: AppSizes.xs,
          margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          decoration: ShapeDecoration(
            color: AppColors.hairline,
            shape: AppShapes.squircle(AppSizes.radiusSm),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                'New promotion',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.huge,
            ),
            children: [
              if (_product != null)
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: ShapeDecoration(
                    color: AppColors.heroPanel,
                    shape: AppShapes.squircle(AppSizes.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(child: Text(_product!.name)),
                      TextButton(
                        onPressed: () => setState(() {
                          _product = null;
                          _searchController.clear();
                          _searchResults = [];
                        }),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search product',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _searchProducts,
                ),
                if (_searching)
                  const LinearProgressIndicator(minHeight: AppSizes.xs),
                for (final p in _searchResults)
                  ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.sku),
                    onTap: () => setState(() {
                      _product = p;
                      _searchResults = [];
                    }),
                  ),
              ],
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _budgetRupees,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total budget (₹)',
                  helperText: 'Lifetime spend cap',
                ),
                // Recompute the daily-cap error when the budget changes.
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _dailyCapRupees,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Daily cap (₹)',
                  helperText: _dailyCapError == null
                      ? 'Auto-pause when reached'
                      : null,
                  errorText: _dailyCapError,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _cpmRupees,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'CPM (₹ per 1000 impressions)',
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Starts'),
                        child: Text(
                          _startAt == null ? 'Pick…' : df.format(_startAt!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Ends'),
                        child: Text(
                          _endAt == null ? 'Pick…' : df.format(_endAt!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Creating…' : 'Create promotion'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
