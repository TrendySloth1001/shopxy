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
import 'package:shopxy/shared/utils/error_text.dart';

/// Create-or-edit sheet for a custom-field [CustomFieldSection].
/// Mirrors [CustomFieldEditorSheet]'s ergonomics: name + icon picker,
/// returns the created/updated section.
class CustomSectionEditorSheet extends StatefulWidget {
  const CustomSectionEditorSheet({super.key, this.existing});

  final CustomFieldSection? existing;

  static Future<CustomFieldSection?> show(
    BuildContext context, {
    CustomFieldSection? existing,
  }) {
    return showModalBottomSheet<CustomFieldSection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => CustomSectionEditorSheet(existing: existing),
    );
  }

  @override
  State<CustomSectionEditorSheet> createState() =>
      _CustomSectionEditorSheetState();
}

class _CustomSectionEditorSheetState extends State<CustomSectionEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  late String? _iconName = widget.existing?.icon;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final provider = context.read<CustomFieldsProvider>();
      final name = _nameController.text.trim();
      CustomFieldSection? result;
      if (widget.existing == null) {
        result = await provider.createSection(name: name, icon: _iconName);
      } else {
        await provider.updateSection(
          widget.existing!.id,
          name: name,
          icon: _iconName,
        );
        for (final s in provider.sections) {
          if (s.id == widget.existing!.id) {
            result = s;
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
        SnackBar(content: Text(friendlyError(e))),
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

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mediaQuery.size.height * 0.85,
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
                Center(
                  child: Container(
                    width: AppSizes.handleWidth,
                    height: AppSizes.handleHeight,
                    decoration: BoxDecoration(
                      color: AppColors.hairline,
                      borderRadius: BorderRadius.circular(AppSizes.radiusXs),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Text(
                  isEditing ? 'Edit section' : 'Add section',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: AppColors.surfaceTint,
                      shape: AppShapes.squircle(
                        AppSizes.radiusSm,
                        side: BorderSide(
                          color: AppColors.hairline,
                          width: 1,
                        ),
                      ),
                      child: SizedBox(
                        width: AppSizes.avatarMd,
                        height: AppSizes.avatarMd,
                        child: Icon(
                          resolveCustomFieldIcon(_iconName),
                          color: AppColors.black,
                          size: AppSizes.iconLg,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Section name',
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
                const SizedBox(height: AppSizes.md),
                Text(
                  'Pick an icon',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                CustomFieldIconPicker(
                  selectedName: _iconName,
                  onChanged: (name) => setState(() => _iconName = name),
                ),
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
