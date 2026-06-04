import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';
import 'package:shopxy/features/custom_fields/presentation/providers/custom_fields_provider.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_icon_picker.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_icons.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';

/// Create-or-edit sheet for a custom field definition.
///
/// Used from:
///   * Settings — managing definitions
///   * Inline `+ Add field` on the product form
///
/// Pre-selecting a `defaultSectionId` lets the caller scope the new
/// field straight into the section the user is editing (saves a tap
/// + reduces "where did my field go" surprise).
class CustomFieldEditorSheet extends StatefulWidget {
  const CustomFieldEditorSheet({
    super.key,
    this.existing,
    this.defaultSectionId,
  });

  final CustomFieldDefinition? existing;
  final int? defaultSectionId;

  static Future<CustomFieldDefinition?> show(
    BuildContext context, {
    CustomFieldDefinition? existing,
    int? defaultSectionId,
  }) {
    return showModalBottomSheet<CustomFieldDefinition>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => CustomFieldEditorSheet(
        existing: existing,
        defaultSectionId: defaultSectionId,
      ),
    );
  }

  @override
  State<CustomFieldEditorSheet> createState() => _CustomFieldEditorSheetState();
}

class _CustomFieldEditorSheetState extends State<CustomFieldEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _unitController =
      TextEditingController(text: widget.existing?.unitSuffix ?? '');
  late final _optionsController = TextEditingController(
    text: widget.existing?.options?.join('\n') ?? '',
  );
  late CustomFieldType _type = widget.existing?.type ?? CustomFieldType.TEXT;
  late String? _iconName = widget.existing?.icon;
  late int? _sectionId = widget.existing?.sectionId ?? widget.defaultSectionId;
  bool _isSaving = false;
  bool _showIconPalette = false;

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  List<String>? _parsedOptions() {
    final lines = _optionsController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    return lines.isEmpty ? null : lines;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_type == CustomFieldType.DROPDOWN &&
        (_parsedOptions()?.length ?? 0) < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least two options for a dropdown.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final provider = context.read<CustomFieldsProvider>();
      final name = _nameController.text.trim();
      final unit = _unitController.text.trim();
      final options =
          _type == CustomFieldType.DROPDOWN ? _parsedOptions() : null;
      final unitSuffix =
          _type == CustomFieldType.NUMBER && unit.isNotEmpty ? unit : null;

      CustomFieldDefinition? result;
      if (widget.existing == null) {
        result = await provider.createDefinition(
          name: name,
          type: _type,
          options: options,
          unitSuffix: unitSuffix,
          icon: _iconName,
          sectionId: _sectionId,
        );
      } else {
        await provider.updateDefinition(
          widget.existing!.id,
          name: name,
          type: _type,
          options: options,
          unitSuffix: unitSuffix,
          icon: _iconName,
        );
        // Re-assign section in a follow-up call so the null case
        // ("ungroup") survives our null-strip JSON serialisation.
        if (_sectionId != widget.existing!.sectionId) {
          await provider.assignToSection(widget.existing!.id, _sectionId);
        }
        // firstWhere would throw if the just-edited field is no
        // longer in [allActiveDefinitions] (e.g. the user archived
        // it concurrently). Falling back to the existing reference
        // is harmless — the sheet just pops successfully.
        for (final d in provider.allActiveDefinitions) {
          if (d.id == widget.existing!.id) {
            result = d;
            break;
          }
        }
        result ??= widget.existing;
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isEditing = widget.existing != null;
    final sections = context.watch<CustomFieldsProvider>().sections;
    final activeSections = sections.where((s) => s.isActive).toList();
    // If the field is currently in a section that's been archived,
    // [activeSections] won't contain it — Dropdown would assert "no
    // item matches value". Pin the displayed value to null in that
    // case (still saveable; user can pick the live section if they
    // want to change it).
    final dropdownSectionValue =
        _sectionId != null && activeSections.any((s) => s.id == _sectionId)
            ? _sectionId
            : null;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppSizes.lg,
            right: AppSizes.lg,
            top: AppSizes.md,
            bottom: mediaQuery.viewInsets.bottom + AppSizes.lg,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GrabHandle(),
                const SizedBox(height: AppSizes.md),
                Text(
                  isEditing
                      ? AppStrings.editCustomField
                      : AppStrings.addCustomField,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IconChip(
                      iconName: _iconName,
                      onTap: () => setState(
                        () => _showIconPalette = !_showIconPalette,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.fieldName,
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        autofocus: !isEditing,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return AppStrings.fieldRequired;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (_showIconPalette) ...[
                  const SizedBox(height: AppSizes.md),
                  CustomFieldIconPicker(
                    selectedName: _iconName,
                    onChanged: (name) => setState(() => _iconName = name),
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                DropdownButtonFormField<CustomFieldType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: AppStrings.fieldType,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in CustomFieldType.values)
                      DropdownMenuItem(value: t, child: Text(t.displayLabel)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _type = v);
                  },
                ),
                if (activeSections.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.md),
                  DropdownButtonFormField<int?>(
                    initialValue: dropdownSectionValue,
                    decoration: const InputDecoration(
                      labelText: 'Section (optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No section'),
                      ),
                      for (final s in activeSections)
                        DropdownMenuItem<int?>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _sectionId = v),
                  ),
                ],
                if (_type == CustomFieldType.NUMBER) ...[
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.unitSuffix,
                      hintText: AppStrings.unitSuffixHint,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_type == CustomFieldType.DROPDOWN) ...[
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _optionsController,
                    decoration: const InputDecoration(
                      labelText: AppStrings.fieldOptions,
                      helperText: AppStrings.fieldOptionsHint,
                      border: OutlineInputBorder(),
                    ),
                    minLines: 3,
                    maxLines: 6,
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                AppButton.primary(
                  label: _isSaving ? AppStrings.loading : AppStrings.save,
                  onPressed: _isSaving ? null : _save,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.iconName, required this.onTap});

  final String? iconName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceTint,
      shape: AppShapes.squircle(
        AppSizes.radiusSm,
        side: const BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusSm),
        child: SizedBox(
          width: AppSizes.fabSize,
          height: AppSizes.fabSize,
          child: Icon(
            resolveCustomFieldIcon(iconName),
            color: AppColors.black,
            size: AppSizes.iconLg,
          ),
        ),
      ),
    );
  }
}

class _GrabHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.xxxl,
        height: AppSizes.xs,
        decoration: BoxDecoration(
          color: AppColors.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
