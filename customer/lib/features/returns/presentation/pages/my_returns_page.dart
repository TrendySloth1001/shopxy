import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/returns/data/datasources/returns_remote_data_source.dart';
import 'package:shopxy_customer/features/returns/domain/return_request.dart';
import 'package:shopxy_customer/features/returns/presentation/pages/return_detail_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';

/// Customer-side list of return requests. Each row links to the
/// return detail page.
class MyReturnsPage extends StatefulWidget {
  const MyReturnsPage({super.key});

  @override
  State<MyReturnsPage> createState() => _MyReturnsPageState();
}

class _MyReturnsPageState extends State<MyReturnsPage> {
  late Future<List<ReturnRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ReturnRequest>> _load() {
    return context.read<ReturnsRemoteDataSource>().list();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Returns'),
      body: FutureBuilder<List<ReturnRequest>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString()
                    .replaceFirst('Exception: ', '')),
              ),
            );
          }
          final items = snap.data ?? const <ReturnRequest>[];
          if (items.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.black,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSizes.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (_, i) => _ReturnRow(returnRequest: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow({required this.returnRequest});
  final ReturnRequest returnRequest;

  @override
  Widget build(BuildContext context) {
    final r = returnRequest;
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReturnDetailPage(returnId: r.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Return #${r.id} · ${r.shop.name}',
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _StatusPill(status: r.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${r.items.length} ${r.items.length == 1 ? "item" : "items"} · ₹${r.refundAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('d MMM y · h:mm a').format(r.createdAt),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  (Color, Color, String) _visuals() {
    switch (status) {
      case 'REFUNDED':
        return (AppColors.success, Colors.white, 'Refunded');
      case 'REJECTED':
        return (AppColors.errorSoft, AppColors.error, 'Rejected');
      case 'CANCELLED':
        return (AppColors.surfaceTint, AppColors.muted, 'Cancelled');
      case 'PICKED_UP':
        return (AppColors.brandSoft, AppColors.brandStrong, 'Picked up');
      case 'RECEIVED':
        return (AppColors.brandSoft, AppColors.brandStrong, 'Received');
      case 'APPROVED':
        return (AppColors.brandSoft, AppColors.brandStrong, 'Approved');
      default:
        return (AppColors.brandSoft, AppColors.brandStrong, 'Requested');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = _visuals();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_return_outlined,
                size: 48, color: AppColors.muted),
            const SizedBox(height: AppSizes.md),
            Text(
              'No returns yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            const Text(
              'When you start a return from an order,\nit\'ll show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
