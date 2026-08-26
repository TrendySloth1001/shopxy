import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class CustomFieldInput extends StatefulWidget {
  const CustomFieldInput({
    super.key,
    required this.definition,
    required this.value,
    required this.onChanged,
  });

  final CustomFieldDefinition definition;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<CustomFieldInput> createState() => _CustomFieldInputState();
}

class _CustomFieldInputState extends State<CustomFieldInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant CustomFieldInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && widget.value != oldWidget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(widget.value) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      widget.onChanged(picked.toIso8601String());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (widget.definition.type) {
      case CustomFieldType.TEXT:
        return TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.definition.name,
            border: const OutlineInputBorder(),
          ),
        );

      case CustomFieldType.LONG_TEXT:
        return TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: widget.definition.name,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        );

      case CustomFieldType.NUMBER:
        return TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.,\-]')),
          ],
          decoration: InputDecoration(
            labelText: widget.definition.name,
            border: const OutlineInputBorder(),
            suffixText: widget.definition.unitSuffix,
          ),
        );

      case CustomFieldType.DATE:
        final parsed = DateTime.tryParse(widget.value);
        final display = parsed == null
            ? ''
            : DateFormat('dd MMM yyyy').format(parsed.toLocal());
        return InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: widget.definition.name,
              border: const OutlineInputBorder(),
              suffixIcon: const AppIcon(AppIcons.calendarTodayRounded),
            ),
            child: Text(
              display.isEmpty ? l10n.customFieldsPickDate : display,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: display.isEmpty ? AppColors.muted : AppColors.black,
              ),
            ),
          ),
        );

      case CustomFieldType.BOOLEAN:
        final boolValue = widget.value == 'true';
        return Container(
          decoration: ShapeDecoration(
            shape: AppShapes.squircle(
              AppSizes.radiusSm,
              side: BorderSide(color: AppColors.hairline, width: 1),
            ),
          ),
          child: SwitchListTile(
            value: boolValue,
            onChanged: (v) => widget.onChanged(v ? 'true' : 'false'),
            title: Text(widget.definition.name),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          ),
        );

      case CustomFieldType.DROPDOWN:
        final options = widget.definition.options ?? const <String>[];
        final isValid = widget.value.isEmpty || options.contains(widget.value);
        return DropdownButtonFormField<String>(
          initialValue: isValid && widget.value.isNotEmpty
              ? widget.value
              : null,
          decoration: InputDecoration(
            labelText: widget.definition.name,
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) => widget.onChanged(v ?? ''),
        );
    }
  }
}
