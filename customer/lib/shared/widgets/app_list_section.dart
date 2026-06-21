import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';

/// A flat list section: an optional uppercase [title] followed by [children]
/// rows laid directly on the page and separated by [AppDivider]s — no bordered
/// "card" container. This is the standard way to present grouped rows
/// (invoices, quotation items …) so screens stay flat and
/// consistent. Rows should be full-width (e.g. a `Padding(Row(...))`).
class AppListSection extends StatelessWidget {
  const AppListSection({
    super.key,
    this.title,
    required this.children,
    this.dividerLeading = 56,
    this.flushDividers = false,
  });

  final String? title;
  final List<Widget> children;

  /// Left indent for the row dividers, to align under text past a leading icon.
  final double dividerLeading;

  /// Use edge-to-edge dividers instead of leading-inset ones.
  final bool flushDividers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: AppSizes.lg,
              right: AppSizes.lg,
              bottom: AppSizes.xs,
            ),
            child: Text(
              title!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
          const AppDivider.flush(),
        ],
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0)
            flushDividers
                ? const AppDivider.flush()
                : AppDivider.inset(leading: dividerLeading),
          children[i],
        ],
      ],
    );
  }
}
