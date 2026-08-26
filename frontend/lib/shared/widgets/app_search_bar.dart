import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.trailing,
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 280),
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final Widget? trailing;

  final bool autofocus;
  final Duration debounce;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  Timer? _debounceTimer;

  TextEditingController? _internalController;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _internalController?.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (widget.debounce == Duration.zero) {
      widget.onChanged(value);
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      if (!mounted) return;
      widget.onChanged(value);
    });
  }

  void _clear() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: AppSizes.huge,
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusFull,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSizes.md),
          AppIcon(
            AppIcons.searchRounded,
            size: AppSizes.iconMd,
            color: AppColors.muted,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              autofocus: widget.autofocus,
              textAlignVertical: TextAlignVertical.center,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: AppSizes.xs),
                child: InkResponse(
                  onTap: _clear,
                  radius: AppSizes.lg,
                  child: AppIcon(
                    AppIcons.closeRounded,
                    size: AppSizes.iconSm,
                    color: AppColors.muted,
                  ),
                ),
              );
            },
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: AppSizes.sm),
            widget.trailing!,
          ],
          const SizedBox(width: AppSizes.md),
        ],
      ),
    );
  }
}
