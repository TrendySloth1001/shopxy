import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

/// Vertical milestone strip for a single per-shop slice's tracking
/// timeline. Renders the canonical lifecycle from CREATED through
/// DELIVERED with a connecting rail; the latest reached milestone
/// gets the accent treatment, future ones render muted.
///
/// Lifecycle vs shipping branches:
///   * REJECTED / CANCELLED short-circuit the timeline at confirm.
///   * RETURNED is rendered as a separate post-delivery row when
///     present.
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.events, required this.status});

  final List<OrderEvent> events;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) return const SizedBox.shrink();

    // Index events by type — only the latest of each kind is shown.
    // Stable across re-orders because the timeline is monotonic.
    final byType = <String, OrderEvent>{};
    for (final e in events) {
      final prev = byType[e.type];
      if (prev == null || e.occurredAt.isAfter(prev.occurredAt)) {
        byType[e.type] = e;
      }
    }

    // Short-circuit branches: rejected / cancelled don't proceed
    // through the shipping rail.
    final terminated = status == 'REJECTED' || status == 'CANCELLED';
    final returned = byType.containsKey('RETURNED');

    final stops = <_Stop>[
      _Stop(
        label: 'Order placed',
        icon: AppIcons.receiptLongRounded,
        event: byType['CREATED'],
      ),
      if (terminated)
        _Stop(
          label: status == 'REJECTED' ? 'Declined by seller' : 'Cancelled',
          icon: AppIcons.cancelOutlined,
          event: byType[status],
          tone: _Tone.danger,
        )
      else ...[
        _Stop(
          label: 'Confirmed',
          icon: AppIcons.checkCircleOutline,
          event: byType['CONFIRMED'],
        ),
        _Stop(
          label: 'Packed',
          icon: AppIcons.inventory2Outlined,
          event: byType['PACKED'],
        ),
        _Stop(
          label: 'Shipped',
          icon: AppIcons.localShippingOutlined,
          event: byType['SHIPPED'],
        ),
        _Stop(
          label: 'Out for delivery',
          icon: AppIcons.directionsRunRounded,
          event: byType['OUT_FOR_DELIVERY'],
        ),
        _Stop(
          label: 'Delivered',
          icon: AppIcons.taskAltRounded,
          event: byType['DELIVERED'],
        ),
      ],
      if (returned)
        _Stop(
          label: 'Returned',
          icon: AppIcons.assignmentReturnOutlined,
          event: byType['RETURNED'],
          tone: _Tone.warning,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracking',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          for (var i = 0; i < stops.length; i++)
            _StopRow(
              stop: stops[i],
              isFirst: i == 0,
              isLast: i == stops.length - 1,
            ),
        ],
      ),
    );
  }
}

enum _Tone { normal, danger, warning }

class _Stop {
  const _Stop({
    required this.label,
    required this.icon,
    this.event,
    this.tone = _Tone.normal,
  });

  final String label;
  final AppIconData icon;
  final OrderEvent? event;
  final _Tone tone;

  bool get reached => event != null;
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.isFirst,
    required this.isLast,
  });
  final _Stop stop;
  final bool isFirst;
  final bool isLast;

  Color _accent() {
    if (!stop.reached) return AppColors.hairline;
    switch (stop.tone) {
      case _Tone.danger:
        return AppColors.error;
      case _Tone.warning:
        return AppColors.warning;
      case _Tone.normal:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accent();
    final reached = stop.reached;
    final e = stop.event;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : (reached ? accent : AppColors.hairline),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: reached ? accent : AppColors.canvas,
                    border: Border.all(
                      color: reached ? accent : AppColors.hairline,
                      width: 2,
                    ),
                  ),
                  child: AppIcon(
                    stop.icon,
                    size: 12,
                    color: reached ? AppColors.white : AppColors.muted,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (reached ? accent : AppColors.hairline),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: reached ? AppColors.black : AppColors.muted,
                      fontWeight: reached ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (e != null) ...[
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      _formatStamp(e.occurredAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    if (e.courier != null || e.awb != null) ...[
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        [
                          if (e.courier != null) e.courier!,
                          if (e.awb != null) 'AWB ${e.awb!}',
                        ].join(' · '),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (e.eta != null) ...[
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        'ETA ${_formatEta(e.eta!)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (e.note != null && e.note!.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        e.note!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.3,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSizes.xs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatStamp(DateTime t) =>
      DateFormat('EEE d MMM · h:mm a').format(t.toLocal());

  static String _formatEta(DateTime t) =>
      DateFormat('EEE d MMM').format(t.toLocal());
}
