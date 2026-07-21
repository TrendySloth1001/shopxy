import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy/features/custom_fields/presentation/providers/custom_fields_provider.dart';
import 'package:shopxy/features/custom_fields/presentation/widgets/custom_field_icons.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Bottom-sheet list of predefined custom-field bundles ("Electronics",
/// "Apparel", "Logistics" …). Tapping a row stamps the whole section
/// + its fields into the shop. Idempotent server-side, so users
/// experimenting can re-tap without piling duplicates.
class TemplatesPickerSheet extends StatefulWidget {
  const TemplatesPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => const TemplatesPickerSheet(),
    );
  }

  @override
  State<TemplatesPickerSheet> createState() => _TemplatesPickerSheetState();
}

class _TemplatesPickerSheetState extends State<TemplatesPickerSheet> {
  String? _applyingId;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    // Templates are normally cached by the provider's full [load],
    // but the picker can be opened before that ever runs (first-time
    // user on the product form's empty state). Fetch them on open
    // when empty so the sheet is never blank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<CustomFieldsProvider>();
      if (p.templates.isEmpty) {
        setState(() => _isFetching = true);
        p.loadTemplates().whenComplete(() {
          if (mounted) setState(() => _isFetching = false);
        });
      }
    });
  }

  Future<void> _apply(String id) async {
    setState(() => _applyingId = id);
    try {
      await context.read<CustomFieldsProvider>().applyTemplate(id);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.customFieldsTemplateApplied)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _applyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final mediaQuery = MediaQuery.of(context);
    final templates = context.watch<CustomFieldsProvider>().templates;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSizes.md),
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
                l10n.customFieldsQuickStartTemplates,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                l10n.customFieldsTemplatesSheetSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              if (templates.isEmpty && _isFetching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (templates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
                  child: Center(
                    child: Text(
                      l10n.customFieldsTemplatesUnavailable,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: AppColors.hairline,
                  ),
                  itemBuilder: (context, i) {
                    final t = templates[i];
                    final isApplying = t.id == _applyingId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: AppSizes.huge,
                        height: AppSizes.huge,
                        decoration: ShapeDecoration(
                          color: AppColors.surfaceTint,
                          shape: AppShapes.squircle(AppSizes.radiusSm),
                        ),
                        child: Icon(
                          resolveCustomFieldIcon(t.icon),
                          color: AppColors.black,
                          size: AppSizes.iconLg,
                        ),
                      ),
                      title: Text(
                        t.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${t.description} · ${l10n.customFieldsTemplateFieldCount(t.fieldCount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      trailing: isApplying
                          ? const SizedBox(
                              width: AppSizes.iconMd,
                              height: AppSizes.iconMd,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              AppIcons.addRounded,
                              color: AppColors.black,
                            ),
                      onTap:
                          _applyingId == null ? () => _apply(t.id) : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSizes.md),
            ],
          ),
        ),
      ),
    );
  }
}
