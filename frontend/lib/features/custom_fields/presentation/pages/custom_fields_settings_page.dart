import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';
import 'package:shopxy/features/custom_fields/presentation/providers/custom_fields_provider.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_editor_sheet.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_icons.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_section_editor_sheet.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/templates_picker_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

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
  Future<void> _addFieldTo(String? sectionId) =>
      CustomFieldEditorSheet.show(context, defaultSectionId: sectionId);
  Future<void> _editField(CustomFieldDefinition d) =>
      CustomFieldEditorSheet.show(context, existing: d);
  Future<void> _showTemplates() => TemplatesPickerSheet.show(context);

  Future<void> _archiveSection(CustomFieldSection s) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.customFieldsArchiveSectionTitle(s.name),
      message: l10n.customFieldsArchiveSectionMessage,
      confirmLabel: l10n.customFieldsArchive,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<CustomFieldsProvider>().deleteSection(s.id);
  }

  Future<void> _archiveField(CustomFieldDefinition d) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.customFieldsArchiveFieldTitle(d.name),
      message: l10n.customFieldsArchiveFieldConfirm,
      confirmLabel: l10n.customFieldsArchive,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<CustomFieldsProvider>().deleteDefinition(d.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<CustomFieldsProvider>();
    final tree = provider.tree;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.customFieldsTitle,
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.autoAwesomeRounded),
            tooltip: l10n.customFieldsTemplates,
            onPressed: _showTemplates,
          ),
          PopupMenuButton<String>(
            icon: const AppIcon(AppIcons.addRounded),
            tooltip: l10n.customFieldsAddField,
            onSelected: (v) {
              if (v == 'section') _addSection();
              if (v == 'field') _addFieldTo(null);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'field',
                child: Text(l10n.customFieldsAddField),
              ),
              PopupMenuItem(
                value: 'section',
                child: Text(l10n.customFieldsAddSection),
              ),
            ],
          ),
        ],
      ),
      body: !provider.hasLoadedOnce && provider.isLoading
          ? const _CustomFieldsSkeleton()
          : tree.isEmpty
          ? _EmptyState(
              onAddField: () => _addFieldTo(null),
              onShowTemplates: _showTemplates,
            )
          : RefreshIndicator(
              onRefresh: () => provider.load(),
              color: AppColors.black,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.md + FloatingAppBar.contentTopInset(context),
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
  const _EmptyState({required this.onAddField, required this.onShowTemplates});

  final VoidCallback onAddField;
  final VoidCallback onShowTemplates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState.line(
      kind: LineArt.boxes,
      title: l10n.customFieldsEmptyTitle,
      subtitle: l10n.customFieldsEmptyHint,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton.primary(
            label: l10n.customFieldsBrowseTemplates,
            icon: AppIcons.autoAwesomeRounded,
            onPressed: onShowTemplates,
          ),
          const SizedBox(height: AppSizes.sm),
          AppButton.ghost(
            label: l10n.customFieldsAddField,
            icon: AppIcons.addRounded,
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
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.tileBg(AppColors.brandSoft),
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: BorderSide(color: AppColors.brand, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              AppIcon(
                AppIcons.autoAwesomeRounded,
                color: AppColors.brandStrong,
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.customFieldsTemplatesCalloutTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.brandStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.customFieldsTemplatesCalloutSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.brandStrong,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.chevronRightRounded,
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
    final l10n = AppLocalizations.of(context);
    final fields = section.fields.where((d) => d.isActive).toList();

    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: BorderSide(color: AppColors.hairline, width: 1),
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
                  AppIcon(
                    resolveCustomFieldIcon(section.icon),
                    color: AppColors.black,
                    size: AppSizes.iconLg,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.name,
                          style: theme.textTheme.titleSmall?.bold,
                        ),
                        Text(
                          fields.length == 1
                              ? l10n.customFieldsFieldCountOne(fields.length)
                              : l10n.customFieldsFieldCountOther(fields.length),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onArchiveSection,
                    icon: AppIcon(
                      AppIcons.archiveAddRounded,
                      color: AppColors.muted,
                    ),
                    tooltip: l10n.customFieldsArchive,
                  ),
                ],
              ),
            ),
          ),
          if (fields.isNotEmpty) Divider(height: 1, color: AppColors.hairline),
          for (int i = 0; i < fields.length; i++) ...[
            _FieldRow(
              field: fields[i],
              onTap: () => onTapField(fields[i]),
              onArchive: () => onArchiveField(fields[i]),
            ),
            if (i < fields.length - 1)
              Divider(
                height: 1,
                color: AppColors.hairline,
                indent: AppSizes.lg,
              ),
          ],
          Divider(height: 1, color: AppColors.hairline),
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
                  AppIcon(AppIcons.addRounded, color: AppColors.muted),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    l10n.customFieldsAddField,
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
    final l10n = AppLocalizations.of(context);
    final active = fields.where((d) => d.isActive).toList();

    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                AppIcon(
                  AppIcons.labelOutlineRounded,
                  color: AppColors.black,
                  size: AppSizes.iconLg,
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.customFieldsNoSection,
                        style: theme.textTheme.titleSmall?.bold,
                      ),
                      Text(
                        active.length == 1
                            ? l10n.customFieldsUngroupedCountOne(active.length)
                            : l10n.customFieldsUngroupedCountOther(
                                active.length,
                              ),
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
          if (active.isNotEmpty) Divider(height: 1, color: AppColors.hairline),
          for (int i = 0; i < active.length; i++) ...[
            _FieldRow(
              field: active[i],
              onTap: () => onTapField(active[i]),
              onArchive: () => onArchiveField(active[i]),
            ),
            if (i < active.length - 1)
              Divider(
                height: 1,
                color: AppColors.hairline,
                indent: AppSizes.lg,
              ),
          ],
          Divider(height: 1, color: AppColors.hairline),
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
                  AppIcon(AppIcons.addRounded, color: AppColors.muted),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    l10n.customFieldsAddField,
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

class _CustomFieldsSkeleton extends StatelessWidget {
  const _CustomFieldsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.huge,
      ),
      children: const [
        _TemplatesCalloutSkeleton(),
        SizedBox(height: AppSizes.lg),
        _SectionCardSkeleton(fieldCount: 2),
        SizedBox(height: AppSizes.md),
        _SectionCardSkeleton(fieldCount: 3),
        SizedBox(height: AppSizes.md),
        _SectionCardSkeleton(fieldCount: 2),
      ],
    );
  }
}

class _TemplatesCalloutSkeleton extends StatelessWidget {
  const _TemplatesCalloutSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmerBox(
      width: double.infinity,
      height: 64,
      radius: AppSizes.radiusMd,
    );
  }
}

class _SectionCardSkeleton extends StatelessWidget {
  const _SectionCardSkeleton({required this.fieldCount});

  final int fieldCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppShimmerBox(
                  width: AppSizes.iconLg,
                  height: AppSizes.iconLg,
                  radius: AppSizes.radiusSm,
                ),
                const SizedBox(width: AppSizes.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmerLine(widthFactor: 0.45, height: 13),
                      SizedBox(height: AppSizes.xs),
                      AppShimmerLine(widthFactor: 0.25, height: 11),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            for (int i = 0; i < fieldCount; i++) ...[
              _FieldRowSkeleton(),
              if (i < fieldCount - 1) const SizedBox(height: AppSizes.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldRowSkeleton extends StatelessWidget {
  const _FieldRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        AppShimmerBox(
          width: AppSizes.iconMd,
          height: AppSizes.iconMd,
          radius: AppSizes.radiusSm,
        ),
        SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerLine(widthFactor: 0.55, height: 13),
              SizedBox(height: AppSizes.xs),
              AppShimmerLine(widthFactor: 0.35, height: 11),
            ],
          ),
        ),
      ],
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

  String _typeSubtitle(AppLocalizations l10n) {
    final parts = <String>[field.type.displayLabel];
    if (field.type == CustomFieldType.NUMBER &&
        field.unitSuffix != null &&
        field.unitSuffix!.isNotEmpty) {
      parts.add(l10n.customFieldsUnitInline(field.unitSuffix!));
    }
    if (field.type == CustomFieldType.DROPDOWN) {
      final count = field.options?.length ?? 0;
      parts.add(
        count == 1
            ? l10n.customFieldsOptionCountOne(count)
            : l10n.customFieldsOptionCountOther(count),
      );
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            AppIcon(
              resolveCustomFieldIcon(field.icon),
              color: AppColors.muted,
              size: AppSizes.iconMd,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.name, style: theme.textTheme.bodyLarge?.semibold),
                  Text(
                    _typeSubtitle(l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: AppIcon(
                AppIcons.archiveAddRounded,
                color: AppColors.muted,
                size: AppSizes.iconMd,
              ),
              tooltip: l10n.customFieldsArchive,
              onPressed: onArchive,
            ),
          ],
        ),
      ),
    );
  }
}
