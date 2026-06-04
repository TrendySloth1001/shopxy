import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// "About this item" bullet list. Renders the first 5 [items] inline;
/// any remainder hides behind a "See more" toggle so a long highlight
/// list doesn't push the spec sheet below the fold. Replaces the old
/// length-heuristic split where chips and bullets were chosen at render
/// time based on whether the first string was short — the heuristic
/// fired on legit short bullets too. Deterministic split is cleaner.
class PdpHighlights extends StatefulWidget {
  const PdpHighlights({super.key, required this.items});
  final List<String> items;

  @override
  State<PdpHighlights> createState() => _PdpHighlightsState();
}

class _PdpHighlightsState extends State<PdpHighlights> {
  static const _collapsedCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final visible = _expanded
        ? widget.items
        : widget.items.take(_collapsedCount).toList();
    final extraCount = widget.items.length - visible.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About this item',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.black,
                ),
          ),
          const SizedBox(height: AppSizes.sm),
          for (final t in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w800,
                          )),
                  Expanded(
                    child: Text(
                      t,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.black,
                            height: 1.45,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          if (extraCount > 0 || _expanded)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xs),
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                  child: Text(
                    _expanded ? 'See less' : 'See more ($extraCount)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
