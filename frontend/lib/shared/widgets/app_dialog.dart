import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/app_button.dart';

/// Standardised confirm dialog. Returns `true` if user confirms.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = AppStrings.confirm,
    this.cancelLabel = AppStrings.cancel,
    this.danger = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool danger;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = AppStrings.confirm,
    String cancelLabel = AppStrings.cancel,
    bool danger = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        danger: danger,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirm = danger
        ? AppButton.danger(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
            fullWidth: true,
          )
        : AppButton.primary(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
            fullWidth: true,
          );

    // Buttons live inside `content` (not `actions`) so they can be full-width
    // Expanded halves of a single row — AlertDialog's `actions` OverflowBar
    // can't bound Expanded children, and would otherwise stack them.
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSizes.xl),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(child: confirm),
            ],
          ),
        ],
      ),
    );
  }
}
