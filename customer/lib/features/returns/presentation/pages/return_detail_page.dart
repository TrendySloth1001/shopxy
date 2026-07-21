import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/returns/data/datasources/returns_remote_data_source.dart';
import 'package:shopxy_customer/features/returns/domain/entities/return_request.dart';
import 'package:shopxy_customer/features/returns/presentation/widgets/return_timeline.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

class ReturnDetailPage extends StatefulWidget {
  const ReturnDetailPage({super.key, required this.returnId});
  final int returnId;

  @override
  State<ReturnDetailPage> createState() => _ReturnDetailPageState();
}

class _ReturnDetailPageState extends State<ReturnDetailPage> {
  ReturnRequest? _data;
  bool _loading = true;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<ReturnsRemoteDataSource>();
      final data = await ds.getById(widget.returnId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _cancel() async {
    final ok = await AppConfirmSheet.show(
      context,
      title: 'Cancel this return?',
      message: 'You\'ll need to start a new return if you change your mind.',
      confirmLabel: 'Cancel return',
      cancelLabel: 'Keep return',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await context.read<ReturnsRemoteDataSource>().cancel(widget.returnId);
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Return cancelled',
        tone: AppSnackbarTone.success,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: friendlyError(e),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppAppBar(title: 'Return #${widget.returnId}'),
      body: _loading
          ? const _ReturnDetailSkeleton()
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(AppSizes.xxl),
                  child: Text(_error!),
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _Body(
                    data: _data!,
                    cancelling: _cancelling,
                    onCancel: _cancel,
                  ),
                ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.data,
    required this.cancelling,
    required this.onCancel,
  });
  final ReturnRequest data;
  final bool cancelling;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        const SizedBox(height: AppSizes.md),
        _HeroCard(data: data),
        const SizedBox(height: AppSizes.md),
        _ItemsCard(items: data.items),
        const SizedBox(height: AppSizes.md),
        _TimelineCard(events: data.events, status: data.status),
        if (data.note != null && data.note!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _NoteBlock(label: 'Your note', text: data.note!),
        ],
        if (data.decisionNote != null && data.decisionNote!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _NoteBlock(
            label: 'Seller\'s note',
            text: data.decisionNote!,
            danger: data.status == 'REJECTED',
          ),
        ],
        if (data.canCancel) ...[
          const SizedBox(height: AppSizes.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
            child: OutlinedButton.icon(
              onPressed: cancelling ? null : onCancel,
              icon: cancelling
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : const Icon(AppIcons.closeRounded, color: AppColors.error),
              label: Text('Cancel return',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                      )),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                shape: AppShapes.squircle(AppSizes.radiusMd),
                side: const BorderSide(color: AppColors.errorSoft),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data});
  final ReturnRequest data;

  @override
  Widget build(BuildContext context) {
    final stamp = DateFormat('d MMM y · h:mm a').format(data.createdAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.shop.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              stamp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'REFUND',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
            Text(
              AppFormat.rupees(data.refundAmount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (data.isRefunded)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.xs),
                child: Text(
                  'Refunded to your original payment method',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});
  final List<ReturnItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i != 0)
                const Divider(
                  height: 1,
                  color: AppColors.hairline,
                  indent: AppSizes.md,
                  endIndent: AppSizes.md,
                ),
              _ItemRow(item: items[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final ReturnItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: AppSizes.productThumbSize,
            height: AppSizes.productThumbSize,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              child: item.imageUrl == null
                  ? Container(color: AppColors.heroPanel)
                  : NetworkImageBox(url: resolveImageUrl(item.imageUrl!)),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)} ${item.unit} · ${reasonLabel(item.reason)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Text(
            AppFormat.rupees(item.refundAmount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events, required this.status});
  final List<ReturnEvent> events;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm,
        ),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: ReturnTimeline(events: events, status: status),
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({
    required this.label,
    required this.text,
    this.danger = false,
  });
  final String label;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppColors.errorSoft : AppColors.surfaceTint;
    final fg = danger ? AppColors.error : AppColors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: bg,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets
// ---------------------------------------------------------------------------

class _ReturnDetailSkeleton extends StatelessWidget {
  const _ReturnDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: const [
        SizedBox(height: AppSizes.md),
        _HeroCardSkeleton(),
        SizedBox(height: AppSizes.md),
        _ItemsCardSkeleton(),
        SizedBox(height: AppSizes.md),
        _TimelineCardSkeleton(),
        SizedBox(height: AppSizes.md),
        _NoteBlockSkeleton(),
      ],
    );
  }
}

class _HeroCardSkeleton extends StatelessWidget {
  const _HeroCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shop name
            AppShimmerLine(widthFactor: 0.45, height: 14),
            SizedBox(height: AppSizes.xs),
            // Timestamp
            AppShimmerLine(widthFactor: 0.6, height: 11),
            SizedBox(height: AppSizes.md),
            // "REFUND" label
            AppShimmerLine(widthFactor: 0.2, height: 10),
            SizedBox(height: AppSizes.xs),
            // Refund amount
            AppShimmerLine(widthFactor: 0.35, height: 24),
          ],
        ),
      ),
    );
  }
}

class _ItemRowSkeleton extends StatelessWidget {
  const _ItemRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(
            width: AppSizes.productThumbSize,
            height: AppSizes.productThumbSize,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.75, height: 13),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.55, height: 11),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const AppShimmerLine(widthFactor: 0.15, height: 13),
        ],
      ),
    );
  }
}

class _ItemsCardSkeleton extends StatelessWidget {
  const _ItemsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i != 0)
                const Divider(
                  height: 1,
                  color: AppColors.hairline,
                  indent: AppSizes.md,
                  endIndent: AppSizes.md,
                ),
              const _ItemRowSkeleton(),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineEventSkeleton extends StatelessWidget {
  const _TimelineEventSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circle indicator
          AppShimmerBox(
            width: AppSizes.iconSm,
            height: AppSizes.iconSm,
            radius: AppSizes.iconSm / 2,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.5, height: 12),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.35, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCardSkeleton extends StatelessWidget {
  const _TimelineCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm,
        ),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: const Column(
          children: [
            _TimelineEventSkeleton(),
            _TimelineEventSkeleton(),
            _TimelineEventSkeleton(),
          ],
        ),
      ),
    );
  }
}

class _NoteBlockSkeleton extends StatelessWidget {
  const _NoteBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.surfaceTint,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppShimmerLine(widthFactor: 0.25, height: 10),
            SizedBox(height: AppSizes.xs),
            AppShimmerLine(widthFactor: 0.9, height: 13),
            SizedBox(height: AppSizes.xs),
            AppShimmerLine(widthFactor: 0.7, height: 13),
          ],
        ),
      ),
    );
  }
}
