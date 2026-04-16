import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.trailing,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSizes.md),
          Icon(
            Icons.search_rounded,
            size: AppSizes.iconMd,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSizes.sm),
            trailing!,
            const SizedBox(width: AppSizes.sm),
          ],
        ],
      ),
    );
  }
}
