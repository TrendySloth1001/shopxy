import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// A centred label pill flanked by hairlines — the app's one way of
/// breaking a scroll into labelled sections.
///
/// Used for day groups in every dated list (notifications, invoices,
/// orders, challans, returns) and for section headings in the menu.
/// Single-sourced so they can never drift apart.
class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key, required this.label, this.icon});

  /// Day-group heading for a dated list: "Today" / "Yesterday" / "12 Jul"
  /// (year appended once the date falls outside the current year).
  SectionDivider.date(DateTime date, {Key? key})
    : this(key: key, label: dateLabel(date));

  final String label;

  /// Optional glyph inside the pill, ahead of the label.
  final AppIconData? icon;

  /// True when [a] and [b] fall on the same calendar day — the day-boundary
  /// test every dated list uses to decide where a divider goes.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Relative day label. Kept beside [isSameDay] so grouping and labelling
  /// always agree about what "a day" means.
  static String dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    if (that == today) return 'Today';
    if (today.difference(that).inDays == 1) return 'Yesterday';
    return (now.year == date.year
            ? DateFormat('d MMM')
            : DateFormat('d MMM yyyy'))
        .format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          const Expanded(child: AppDivider.flush()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.xs,
              ),
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: AppShapes.squircle(
                  AppSizes.radiusFull,
                  side: BorderSide(color: AppColors.hairline),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    AppIcon(
                      icon,
                      size: AppSizes.iconSm,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: AppSizes.xs),
                  ],
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(child: AppDivider.flush()),
        ],
      ),
    );
  }
}
