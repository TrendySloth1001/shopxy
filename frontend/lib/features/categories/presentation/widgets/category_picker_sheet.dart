import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Two-level tree picker over the canonical taxonomy. Replaces the
/// flat searchable list — categories are fixed and curated now, so the
/// browse pattern (parent → child) matches how merchants think about
/// where their product lives.
///
/// The picker only commits a *leaf* selection; tapping a parent expands
/// it inline. A "Clear" footer surfaces when there's already a current
/// pick.
class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({super.key, required this.currentSelectionId});

  final int? currentSelectionId;

  static Future<CategoryPickerResult?> show(
    BuildContext context, {
    required int? currentSelectionId,
  }) {
    return showModalBottomSheet<CategoryPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) =>
          CategoryPickerSheet(currentSelectionId: currentSelectionId),
    );
  }

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  List<CategoryNode> _tree = const [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    // If the current selection is a leaf, pre-expand its parent so the
    // user lands on it visually without scrolling-and-tapping.
    _load();
  }

  Future<void> _load() async {
    final ds = context.read<CategoriesRemoteDataSource>();
    try {
      final tree = await ds.getTree(activeOnly: true);
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _isLoading = false;
        // Auto-expand any parent whose subtree contains the current
        // selection so the user can confirm what's picked at a glance.
        for (final p in tree) {
          if (p.children.any((c) => c.category.id == widget.currentSelectionId)) {
            _expanded.add(p.category.id);
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  void _pick(Category? category) {
    Navigator.of(context).pop(
      CategoryPickerResult(
        categoryId: category?.id,
        categoryName: category?.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.82;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            top: AppSizes.md,
            bottom: mediaQuery.viewInsets.bottom + AppSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GrabHandle(),
              const SizedBox(height: AppSizes.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.selectCategory,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: AppStrings.cancel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Flexible(child: _buildBody(theme)),
              if (widget.currentSelectionId != null) ...[
                const Divider(color: AppColors.hairline, height: 1),
                TextButton.icon(
                  onPressed: () => _pick(null),
                  icon: const Icon(Icons.close_rounded, size: AppSizes.iconSm),
                  label: const Text(AppStrings.clearSelection),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
        child: Text(
          AppStrings.error,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
        ),
      );
    }
    if (_tree.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
        child: Center(
          child: Text(
            AppStrings.noCategoriesMatch,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      itemCount: _tree.length,
      itemBuilder: (context, index) {
        final parent = _tree[index];
        final expanded = _expanded.contains(parent.category.id);
        return _ParentRow(
          parent: parent,
          expanded: expanded,
          currentSelectionId: widget.currentSelectionId,
          onToggle: () {
            setState(() {
              if (expanded) {
                _expanded.remove(parent.category.id);
              } else {
                _expanded.add(parent.category.id);
              }
            });
          },
          onPickChild: _pick,
          onPickParent: parent.children.isEmpty ? _pick : null,
        );
      },
    );
  }
}

class _ParentRow extends StatelessWidget {
  const _ParentRow({
    required this.parent,
    required this.expanded,
    required this.currentSelectionId,
    required this.onToggle,
    required this.onPickChild,
    required this.onPickParent,
  });

  final CategoryNode parent;
  final bool expanded;
  final int? currentSelectionId;
  final VoidCallback onToggle;
  final ValueChanged<Category?> onPickChild;
  /// When the parent has no children, tapping the row picks it directly
  /// instead of toggling (otherwise the parent is unpickable).
  final ValueChanged<Category?>? onPickParent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = parent.category.id == currentSelectionId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onPickParent != null
              ? () => onPickParent!(parent.category)
              : onToggle,
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: Row(
              children: [
                _CategoryThumb(category: parent.category, size: AppSizes.huge),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parent.category.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      if (parent.children.isNotEmpty)
                        Text(
                          '${parent.children.length} subcategories',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (parent.children.isEmpty)
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.chevron_right_rounded,
                    color: isSelected ? AppColors.brand : AppColors.muted,
                  )
                else
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                  ),
              ],
            ),
          ),
        ),
        if (expanded && parent.children.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              // Indent child chips to clear the parent thumbnail column
              // (thumb width `huge` + row gap `md`).
              left: AppSizes.huge + AppSizes.md,
              bottom: AppSizes.sm,
            ),
            child: Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final child in parent.children)
                  _ChildChip(
                    category: child.category,
                    isSelected: child.category.id == currentSelectionId,
                    onTap: () => onPickChild(child.category),
                  ),
              ],
            ),
          ),
        const Divider(height: 1, color: AppColors.hairline),
      ],
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusXl),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.xs,
        ),
        decoration: ShapeDecoration(
          color: isSelected ? AppColors.black : AppColors.surfaceTint,
          shape: AppShapes.squircle(AppSizes.radiusXl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CategoryThumb(category: category, size: AppSizes.xl, rounded: true),
            const SizedBox(width: AppSizes.xs),
            Text(
              category.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? AppColors.white : AppColors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: AppSizes.xs),
              const Icon(
                Icons.check_rounded,
                size: AppSizes.iconSm,
                color: AppColors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thumbnail used in the parent row and child chip. Falls back to the
/// iconName-derived glyph over a tint when the URL is empty or the
/// load errors.
class _CategoryThumb extends StatelessWidget {
  const _CategoryThumb({
    required this.category,
    required this.size,
    this.rounded = true,
  });
  final Category category;
  final double size;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final url = category.imageUrl;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius:
            BorderRadius.circular(rounded ? size / 2 : AppSizes.radiusSm),
      ),
      alignment: Alignment.center,
      child: Icon(
        resolveCategoryIcon(category.iconName),
        color: AppColors.black,
        size: size * 0.55,
      ),
    );
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(rounded ? size / 2 : AppSizes.radiusSm),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

/// Returned from [CategoryPickerSheet.show]. `categoryId == null` with
/// a non-null result means the user explicitly cleared the selection;
/// a `null` result means the sheet was dismissed without choosing.
class CategoryPickerResult {
  const CategoryPickerResult({required this.categoryId, this.categoryName});
  final int? categoryId;
  final String? categoryName;
}

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.xxxl,
        height: AppSizes.xs,
        decoration: ShapeDecoration(
          color: AppColors.hairline,
          shape: AppShapes.squircle(AppSizes.radiusSm),
        ),
      ),
    );
  }
}
