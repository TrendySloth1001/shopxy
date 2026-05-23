import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';
import 'package:shopxy/features/custom_fields/presentation/providers/custom_fields_provider.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_editor_sheet.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_icons.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_section_editor_sheet.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/templates_picker_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

/// Settings → Custom Fields.
///
/// Tree-style layout: each [CustomFieldSection] is a collapsible card
/// listing its own fields. Ungrouped fields render in a "No section"
/// bucket at the top so they're easy to find + organise. Templates
/// available as a one-tap stamp from the AppBar.
class CustomFieldsSettingsPage extends StatefulWidget {
  const CustomFieldsSettingsPage({super.key});

  @override
  State<CustomFieldsSettingsPage> createState() =>
      _CustomFieldsSettingsPageState();
}

class _CustomFieldsSettingsPageState extends State<CustomFieldsSettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CustomFieldsProvider>().load();
    });
  }

  Future<void> _addSection() => CustomSectionEditorSheet.show(context);
  Future<void> _editSection(CustomFieldSection s) =>
      CustomSectionEditorSheet.show(context, existing: s);
  Future<void> _addFieldTo(int? sectionId) =>
      CustomFieldEditorSheet.show(context, defaultSectionId: sectionId);
  Future<void> _editField(CustomFieldDefinition d) =>
      CustomFieldEditorSheet.show(context, existing: d);
  Future<void> _showTemplates() => TemplatesPickerSheet.show(context);

  Future<void> _archiveSection(CustomFieldSection s) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Archive "${s.name}"?',
      message:
          'Archiving hides the section. Its fields stay where they are and can be reassigned later.',
      confirmLabel: AppStrings.archive,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<CustomFieldsProvider>().deleteSection(s.id);
  }

  Future<void> _archiveField(CustomFieldDefinition d) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: '${AppStrings.archive} "${d.name}"?',
      message: AppStrings.archiveCustomFieldConfirm,
      confirmLabel: AppStrings.archive,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<CustomFieldsProvider>().deleteDefinition(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomFieldsProvider>();
    final tree = provider.tree;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.customFields),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            tooltip: 'Templates',
            onPressed: _showTemplates,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_rounded),
            tooltip: AppStrings.addCustomField,
            onSelected: (v) {
              if (v == 'section') _addSection();
              if (v == 'field') _addFieldTo(null);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'field', child: Text('Add field')),
              PopupMenuItem(value: 'section', child: Text('Add section')),
            ],
          ),
        ],
      ),
      body: !provider.hasLoadedOnce && provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : tree.isEmpty
              ? _EmptyState(
                  onAddField: () => _addFieldTo(null),
                  onShowTemplates: _showTemplates,
                )
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  color: AppColors.black,
                  backgroundColor: AppColors.white,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.lg,
                      AppSizes.md,
                      AppSizes.lg,
                      AppSizes.huge,
                    ),
                    children: [
                      _TemplatesCallout(onTap: _showTemplates),
                      const SizedBox(height: AppSizes.lg),
                      if (tree.ungrouped.isNotEmpty) ...[
                        _UngroupedSectionCard(
                          fields: tree.ungrouped,
                          onAddField: () => _addFieldTo(null),
                          onTapField: _editField,
                          onArchiveField: _archiveField,
                        ),
                        const SizedBox(height: AppSizes.md),
                      ],
                      for (final section in tree.sections) ...[
                        _SectionCard(
                          section: section,
                          onAddField: () => _addFieldTo(section.id),
                          onEditSection: () => _editSection(section),
                          onArchiveSection: () => _archiveSection(section),
                          onTapField: _editField,
                          onArchiveField: _archiveField,
                        ),
                        const SizedBox(height: AppSizes.md),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onAddField,
    required this.onShowTemplates,
  });

  final VoidCallback onAddField;
  final VoidCallback onShowTemplates;

  @override
  Widget build(BuildContext context) {
    return EmptyState.line(
      kind: LineArt.boxes,
      title: AppStrings.customFieldsEmptyTitle,
      subtitle: AppStrings.customFieldsEmptyHint,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton.primary(
            label: 'Browse templates',
            icon: Icons.auto_awesome_rounded,
            onPressed: onShowTemplates,
          ),
          const SizedBox(height: AppSizes.sm),
          AppButton.ghost(
            label: AppStrings.addCustomField,
            icon: Icons.add_rounded,
            onPressed: onAddField,
          ),
        ],
      ),
    );
  }
}

class _TemplatesCallout extends StatelessWidget {
  const _TemplatesCallout({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.brandSoft,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.brand, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.brandStrong,
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stamp a quick-start template',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.brandStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Electronics, Apparel, Logistics, Food, Warranty…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.brandStrong,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.brandStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.onAddField,
    required this.onEditSection,
    required this.onArchiveSection,
    required this.onTapField,
    required this.onArchiveField,
  });

  final CustomFieldSection section;
  final VoidCallback onAddField;
  final VoidCallback onEditSection;
  final VoidCallback onArchiveSection;
  final ValueChanged<CustomFieldDefinition> onTapField;
  final ValueChanged<CustomFieldDefinition> onArchiveField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = section.fields.where((d) => d.isActive).toList();

    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onEditSection,
            customBorder: AppShapes.squircle(AppSizes.radiusMd),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md,
                AppSizes.md,
                AppSizes.xs,
                AppSizes.md,
              ),
              child: Row(
                children: [
                  Icon(
                    resolveCustomFieldIcon(section.icon),
                    color: AppColors.black,
                    size: 22,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${fields.length} field${fields.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onArchiveSection,
                    icon: const Icon(
                      Icons.archive_outlined,
                      color: AppColors.muted,
                    ),
                    tooltip: AppStrings.archive,
                  ),
                ],
              ),
            ),
          ),
          if (fields.isNotEmpty)
            const Divider(height: 1, color: AppColors.hairline),
          for (int i = 0; i < fields.length; i++) ...[
            _FieldRow(
              field: fields[i],
              onTap: () => onTapField(fields[i]),
              onArchive: () => onArchiveField(fields[i]),
            ),
            if (i < fields.length - 1)
              const Divider(
                height: 1,
                color: AppColors.hairline,
                indent: AppSizes.lg,
              ),
          ],
          const Divider(height: 1, color: AppColors.hairline),
          InkWell(
            onTap: onAddField,
            customBorder: AppShapes.squircle(AppSizes.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.muted),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    AppStrings.addCustomField,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UngroupedSectionCard extends StatelessWidget {
  const _UngroupedSectionCard({
    required this.fields,
    required this.onAddField,
    required this.onTapField,
    required this.onArchiveField,
  });

  final List<CustomFieldDefinition> fields;
  final VoidCallback onAddField;
  final ValueChanged<CustomFieldDefinition> onTapField;
  final ValueChanged<CustomFieldDefinition> onArchiveField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = fields.where((d) => d.isActive).toList();

    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                const Icon(
                  Icons.label_outline_rounded,
                  color: AppColors.black,
                  size: 22,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No section',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${active.length} ungrouped field${active.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (active.isNotEmpty)
            const Divider(height: 1, color: AppColors.hairline),
          for (int i = 0; i < active.length; i++) ...[
            _FieldRow(
              field: active[i],
              onTap: () => onTapField(active[i]),
              onArchive: () => onArchiveField(active[i]),
            ),
            if (i < active.length - 1)
              const Divider(
                height: 1,
                color: AppColors.hairline,
                indent: AppSizes.lg,
              ),
          ],
          const Divider(height: 1, color: AppColors.hairline),
          InkWell(
            onTap: onAddField,
            customBorder: AppShapes.squircle(AppSizes.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.md,
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, color: AppColors.muted),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    AppStrings.addCustomField,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.onTap,
    required this.onArchive,
  });

  final CustomFieldDefinition field;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  String _typeSubtitle() {
    final parts = <String>[field.type.displayLabel];
    if (field.type == CustomFieldType.NUMBER &&
        field.unitSuffix != null &&
        field.unitSuffix!.isNotEmpty) {
      parts.add('in ${field.unitSuffix}');
    }
    if (field.type == CustomFieldType.DROPDOWN) {
      final count = field.options?.length ?? 0;
      parts.add('$count option${count == 1 ? '' : 's'}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm + 2,
        ),
        child: Row(
          children: [
            Icon(
              resolveCustomFieldIcon(field.icon),
              color: AppColors.muted,
              size: 20,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _typeSubtitle(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.archive_outlined,
                color: AppColors.muted,
                size: 20,
              ),
              tooltip: AppStrings.archive,
              onPressed: onArchive,
            ),
          ],
        ),
      ),
    );
  }
}
