import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy/features/custom_fields/presentation/providers/custom_fields_provider.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_editor_sheet.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_icons.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_input.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_section_editor_sheet.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/templates_picker_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// "More about this product" — drops into Add/Edit Product.
///
/// Renders the shop's custom-field tree as a grouped form: section
/// header (icon + name) followed by its fields, then ungrouped
/// fields. Inline affordances let the user add a brand-new section
/// or field without leaving the form, and apply a quick-start
/// template when they have nothing yet.
class CustomFieldsFormSection extends StatefulWidget {
  const CustomFieldsFormSection({
    super.key,
    required this.values,
    required this.onValueChanged,
  });

  final Map<int, String> values;
  final void Function(int definitionId, String value) onValueChanged;

  @override
  State<CustomFieldsFormSection> createState() =>
      _CustomFieldsFormSectionState();
}

class _CustomFieldsFormSectionState extends State<CustomFieldsFormSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<CustomFieldsProvider>();
      if (!p.hasLoadedOnce && !p.isLoading) {
        p.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<CustomFieldsProvider>();
    final tree = provider.tree;

    if (tree.isEmpty) {
      return _EmptyHint(
        theme: theme,
        onAddField: () => CustomFieldEditorSheet.show(context),
        onShowTemplates: () => TemplatesPickerSheet.show(context),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tree.ungrouped.isNotEmpty) ...[
          for (final def in tree.ungrouped.where((d) => d.isActive)) ...[
            CustomFieldInput(
              key: ValueKey('cf-${def.id}'),
              definition: def,
              value: widget.values[def.id] ?? '',
              onChanged: (v) => widget.onValueChanged(def.id, v),
            ),
            const SizedBox(height: AppSizes.md),
          ],
        ],
        for (final section in tree.sections.where((s) => s.isActive))
          if (section.fields.any((d) => d.isActive))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.md),
              child: _SectionGroup(
                title: section.name,
                icon: resolveCustomFieldIcon(section.icon),
                child: Column(
                  children: [
                    for (final def
                        in section.fields.where((d) => d.isActive)) ...[
                      CustomFieldInput(
                        key: ValueKey('cf-${def.id}'),
                        definition: def,
                        value: widget.values[def.id] ?? '',
                        onChanged: (v) => widget.onValueChanged(def.id, v),
                      ),
                      const SizedBox(height: AppSizes.md),
                    ],
                  ],
                ),
              ),
            ),
        const SizedBox(height: AppSizes.xs),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            AppButton.secondary(
              label: l10n.customFieldsAddField,
              icon: AppIcons.addRounded,
              onPressed: () => CustomFieldEditorSheet.show(context),
            ),
            AppButton.ghost(
              label: l10n.customFieldsAddSection,
              icon: AppIcons.folderOutlined,
              onPressed: () => CustomSectionEditorSheet.show(context),
            ),
            AppButton.ghost(
              label: l10n.customFieldsTemplates,
              icon: AppIcons.autoAwesomeRounded,
              onPressed: () => TemplatesPickerSheet.show(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        AppSizes.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSizes.iconMd, color: AppColors.black),
              const SizedBox(width: AppSizes.sm),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.theme,
    required this.onAddField,
    required this.onShowTemplates,
  });
  final ThemeData theme;
  final VoidCallback onAddField;
  final VoidCallback onShowTemplates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      decoration: ShapeDecoration(
        color: AppColors.surfaceTint,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.customFieldsEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              AppButton.secondary(
                label: l10n.customFieldsAddField,
                icon: AppIcons.addRounded,
                onPressed: onAddField,
              ),
              AppButton.ghost(
                label: l10n.customFieldsBrowseTemplates,
                icon: AppIcons.autoAwesomeRounded,
                onPressed: onShowTemplates,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
