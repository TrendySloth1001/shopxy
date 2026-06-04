import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Phase E — variant swatch picker. Shows one chip row per axis. The
/// currently-selected variant is whichever row matches all selected
/// axis values. Returns null while the selection is incomplete so the
/// caller can fall back to the default variant.
class PdpVariantPicker extends StatefulWidget {
  const PdpVariantPicker({
    super.key,
    required this.product,
    required this.onSelect,
  });

  final MarketplaceProduct product;
  final ValueChanged<MarketplaceVariant> onSelect;

  @override
  State<PdpVariantPicker> createState() => _PdpVariantPickerState();
}

class _PdpVariantPickerState extends State<PdpVariantPicker> {
  late Map<String, String> _selected;

  @override
  void initState() {
    super.initState();
    // Seed selection from the default variant so we always have a
    // canonical row to drive the price block.
    final def = widget.product.defaultVariant;
    _selected = {
      for (final a in widget.product.variantAxes)
        a.name: def?.attributes[a.name] ?? a.values.first,
    };
    // Edge case — when default variant has empty attributes (single-
    // variant product), seed from the first axis value of each axis.
  }

  MarketplaceVariant? _matchVariant() {
    for (final v in widget.product.variants) {
      bool match = true;
      for (final entry in _selected.entries) {
        if (v.attributes[entry.key] != entry.value) {
          match = false;
          break;
        }
      }
      if (match) return v;
    }
    return null;
  }

  void _pick(String axis, String value) {
    setState(() => _selected = {..._selected, axis: value});
    final v = _matchVariant();
    if (v != null) widget.onSelect(v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.product.variants.length <= 1 ||
        widget.product.variantAxes.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.sm, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final axis in widget.product.variantAxes) ...[
            Row(
              children: [
                Text(
                  '${axis.name}: ',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Flexible(
                  child: Text(
                    _selected[axis.name] ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final v in axis.values)
                  GestureDetector(
                    onTap: () => _pick(axis.name, v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md, vertical: AppSizes.sm),
                      decoration: BoxDecoration(
                        color: _selected[axis.name] == v
                            ? AppColors.brand
                            : AppColors.white,
                        border: Border.all(
                          color: _selected[axis.name] == v
                              ? AppColors.brand
                              : AppColors.hairline,
                          width: 1.5,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        v,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _selected[axis.name] == v
                                  ? AppColors.white
                                  : AppColors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
          ],
        ],
      ),
    );
  }
}
