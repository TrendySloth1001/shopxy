import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';

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

  final double dividerLeading;

  final bool flushDividers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              style: theme.textTheme.labelSmall?.copyWith(
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
