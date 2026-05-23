import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';

/// Searchable, paginated category picker. Replaces the inline pill
/// strip on the Products page once a shop has more categories than
/// fit across a phone width — keeps the chassis usable at 10 or
/// 10,000 categories.
///
/// Pagination is server-side via
/// [CategoriesRemoteDataSource.searchCategories]; this sheet just
/// asks for the next page when the user scrolls near the end.
class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({super.key, required this.currentSelectionId});

  /// Currently-selected category id, so we can highlight the active
  /// row and offer a "Clear selection" footer.
  final int? currentSelectionId;

  /// Convenience: show the sheet and return the user's choice (or
  /// `null` if dismissed without choosing).
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
  static const _pageSize = 50;
  static const _debounce = Duration(milliseconds: 220);

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  List<Category> _items = const [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  Timer? _debounceTimer;
  // Each fetch tags itself with this counter so stale responses
  // (slow network, type-ahead) never overwrite the latest result.
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => _fetch(reset: true));
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _items.length < _total) {
      _fetch(reset: false);
    }
  }

  Future<void> _fetch({required bool reset}) async {
    final ds = context.read<CategoriesRemoteDataSource>();
    final seq = ++_requestSeq;
    final query = _searchController.text.trim();

    setState(() {
      if (reset) {
        _isLoading = true;
        _page = 1;
      } else {
        _isLoadingMore = true;
        _page += 1;
      }
      _error = null;
    });

    try {
      final result = await ds.searchCategories(
        search: query.isEmpty ? null : query,
        page: reset ? 1 : _page,
        limit: _pageSize,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _items = reset ? result.categories : [..._items, ...result.categories];
        _total = result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
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
    final maxHeight = mediaQuery.size.height * 0.78;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSizes.lg,
            right: AppSizes.lg,
            top: AppSizes.md,
            bottom: mediaQuery.viewInsets.bottom + AppSizes.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _GrabHandle(),
              const SizedBox(height: AppSizes.md),
              Row(
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
              const SizedBox(height: AppSizes.sm),
              AppSearchBar(
                hint: AppStrings.searchCategories,
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: AppSizes.md),
              Flexible(child: _buildBody(theme)),
              if (widget.currentSelectionId != null) ...[
                const Divider(color: AppColors.hairline, height: 1),
                TextButton.icon(
                  onPressed: () => _pick(null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text(AppStrings.clearSelection),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
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
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
        child: Center(
          child: Text(
            AppStrings.noCategoriesMatch,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.muted,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      shrinkWrap: true,
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.hairline),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _categoryTile(_items[index], theme);
      },
    );
  }

  Widget _categoryTile(Category category, ThemeData theme) {
    final isSelected = category.id == widget.currentSelectionId;
    final count = category.productCount;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        category.name,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: count != null
          ? Text(
              '$count ${count == 1 ? 'product' : 'products'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            )
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.brand)
          : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: () => _pick(category),
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
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.hairline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
