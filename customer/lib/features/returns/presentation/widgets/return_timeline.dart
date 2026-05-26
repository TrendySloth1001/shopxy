import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy_customer/features/returns/domain/return_request.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Vertical milestone strip for a return request. Short-circuits to
/// REJECTED / CANCELLED when terminated early.
class ReturnTimeline extends StatelessWidget {
  const ReturnTimeline({super.key, required this.events, required this.status});
  final List<ReturnEvent> events;
  final String status;

  @override
  Widget build(BuildContext context) {
    final byType = <String, ReturnEvent>{};
    for (final e in events) {
      final prev = byType[e.type];
      if (prev == null || e.occurredAt.isAfter(prev.occurredAt)) {
        byType[e.type] = e;
      }
    }
    final rejected = status == 'REJECTED';
    final cancelled = status == 'CANCELLED';

    final stops = <_Stop>[
      _Stop('Requested', Icons.receipt_rounded, byType['REQUESTED']),
      if (rejected)
        _Stop('Rejected', Icons.cancel_outlined, byType['REJECTED'],
            tone: _Tone.danger)
      else if (cancelled)
        _Stop('Cancelled', Icons.cancel_outlined, byType['CANCELLED'],
            tone: _Tone.warn)
      else ...[
        _Stop('Approved', Icons.check_circle_outline, byType['APPROVED']),
        _Stop('Picked up', Icons.local_shipping_outlined, byType['PICKED_UP']),
        _Stop('Received', Icons.inventory_2_outlined, byType['RECEIVED']),
        _Stop('Refunded', Icons.account_balance_wallet_outlined,
            byType['REFUNDED']),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TIMELINE',
          style: TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.5,
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
    );
  }
}

enum _Tone { normal, danger, warn }

class _Stop {
  const _Stop(this.label, this.icon, this.event, {this.tone = _Tone.normal});
  final String label;
  final IconData icon;
  final ReturnEvent? event;
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
      case _Tone.warn:
        return Colors.orange.shade700;
      case _Tone.normal:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Icon(
                    stop.icon,
                    size: 12,
                    color: reached ? Colors.white : AppColors.muted,
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.label,
                    style: TextStyle(
                      color: reached ? AppColors.black : AppColors.muted,
                      fontWeight:
                          reached ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (e != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEE d MMM · h:mm a').format(e.occurredAt.toLocal()),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
