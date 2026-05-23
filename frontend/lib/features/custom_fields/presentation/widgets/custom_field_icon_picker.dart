import 'package:flutter/material.dart';

import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_icons.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Grid picker over the curated [kCustomFieldIcons] palette. Tap an
/// icon to select; tapping the same icon clears the choice. Designed
/// to drop into the section / field editor sheets via an `Align +
/// Wrap`-style affordance.
class CustomFieldIconPicker extends StatelessWidget {
  const CustomFieldIconPicker({
    super.key,
    required this.selectedName,
    required this.onChanged,
  });

  final String? selectedName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = kCustomFieldIcons.entries.toList();
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.sm,
      children: [
        for (final entry in entries)
          _IconTile(
            name: entry.key,
            icon: entry.value,
            selected: entry.key == selectedName,
            onTap: () =>
                onChanged(entry.key == selectedName ? null : entry.key),
          ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.black : AppColors.surfaceTint,
      shape: AppShapes.squircle(
        AppSizes.radiusSm,
        side: BorderSide(
          color: selected ? AppColors.black : AppColors.hairline,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusSm),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: selected ? AppColors.white : AppColors.black,
            size: 22,
          ),
        ),
      ),
    );
  }
}
