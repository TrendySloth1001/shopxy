import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Platform-admin editor for the marketplace taxonomy tree. Each node
/// is rendered as an expandable tile; tapping it opens an inline editor
/// for rename / re-parent / activate / delete. Re-parenting uses the
/// flat list as the "Parent" dropdown (filtered to avoid offering the
/// node's own subtree, which the backend would reject anyway as a cycle).
class AdminCategoryTaxonomyPage extends StatefulWidget {
  const AdminCategoryTaxonomyPage({super.key});

  @override
  State<AdminCategoryTaxonomyPage> createState() =>
      _AdminCategoryTaxonomyPageState();
}

class _AdminCategoryTaxonomyPageState extends State<AdminCategoryTaxonomyPage> {
  late final CategoriesRemoteDataSource _ds;
  List<CategoryNode> _tree = [];
  List<Category> _flat = []; // flattened for the parent picker
  bool _loading = true;
  String? _error;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _ds = context.read<CategoriesRemoteDataSource>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tree = await _ds.getTree();
      final flat = <Category>[];
      void walk(List<CategoryNode> ns) {
        for (final n in ns) {
          flat.add(n.category);
          walk(n.children);
        }
      }
      walk(tree);
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _flat = flat;
        _loading = false;
        // Expand all root nodes by default so the page isn't a wall
        // of collapsed cards.
        for (final n in tree) {
          _expanded.add(n.category.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _createRoot() async {
    final created = await _openEditor(parentId: null);
    if (created == true) await _load();
  }

  Future<void> _createChild(int parentId) async {
    final created = await _openEditor(parentId: parentId);
    if (created == true) await _load();
  }

  Future<bool?> _openEditor({
    Category? existing,
    int? parentId,
  }) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, _) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: _CategoryEditorSheet(
            existing: existing,
            initialParentId: parentId,
            // Filter out `existing` itself + any of its descendants so
            // the parent picker never lets the admin pick a value the
            // backend will reject as a cycle.
            availableParents: existing == null
                ? _flat
                : _flat
                    .where((c) =>
                        c.id != existing.id &&
                        !_isDescendantOf(c.id, existing.id))
                    .toList(),
            ds: _ds,
          ),
        ),
      ),
    );
  }

  /// O(n) walk up via `parentId`. Returns true iff `candidateId` lives
  /// somewhere under `ancestorId`. Used to scrub the parent-picker
  /// option list during re-parenting.
  bool _isDescendantOf(int candidateId, int ancestorId) {
    int? cursor = candidateId;
    for (int i = 0; i < 32 && cursor != null; i++) {
      final parent = _flat.firstWhere(
        (c) => c.id == cursor,
        orElse: () => _flat.first,
      );
      if (parent.parentId == ancestorId) return true;
      cursor = parent.parentId;
    }
    return false;
  }

  Future<void> _delete(Category c) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminCategoryDeleteTitle(c.name)),
        content: Text(l10n.adminCategoryDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.adminCancel),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorSoft,
              foregroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.adminDelete),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _ds.deleteCategory(c.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.adminCategoryTaxonomyTitle,
        actions: [
          IconButton(
            tooltip: l10n.adminRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoot,
        icon: const Icon(Icons.add),
        label: Text(l10n.adminCategoryRoot),
      ),
      body: _loading && _tree.isEmpty
          ? const _CategoryListSkeleton()
          : _error != null && _tree.isEmpty
              ? SafeArea(
                  top: true,
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.xl),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.lg,
                      AppSizes.lg + FloatingAppBar.contentTopInset(context),
                      AppSizes.lg,
                      AppSizes.fabClearance,
                    ),
                    children: [
                      for (final n in _tree)
                        _CategoryTreeTile(
                          node: n,
                          depth: 0,
                          expanded: _expanded,
                          onToggle: (id) => setState(() {
                            if (_expanded.contains(id)) {
                              _expanded.remove(id);
                            } else {
                              _expanded.add(id);
                            }
                          }),
                          onEdit: (c) async {
                            final ok = await _openEditor(existing: c);
                            if (ok == true) await _load();
                          },
                          onAddChild: (id) => _createChild(id),
                          onDelete: _delete,
                        ),
                    ],
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets — shown while the taxonomy tree is loading.
// ---------------------------------------------------------------------------

/// A single shimmer tile that mirrors the card layout of [_CategoryTreeTile].
class _CategoryTileSkeleton extends StatelessWidget {
  const _CategoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.sm),
          child: Row(
            children: [
              // Chevron icon skeleton
              const SizedBox(
                width: AppSizes.iconMd + AppSizes.sm * 2,
                height: AppSizes.iconMd + AppSizes.sm * 2,
                child: Center(
                  child: AppShimmerBox(
                    width: AppSizes.iconMd,
                    height: AppSizes.iconMd,
                    radius: AppSizes.radiusSm,
                  ),
                ),
              ),
              // Category icon box (32×32 coloured square)
              const AppShimmerBox(width: 32, height: 32, radius: AppSizes.radiusSm),
              const SizedBox(width: AppSizes.sm),
              // Title + subtitle lines
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmerLine(widthFactor: 0.60, height: 13),
                    SizedBox(height: 4),
                    AppShimmerLine(widthFactor: 0.40, height: 10),
                  ],
                ),
              ),
              // Action icon placeholders
              const AppShimmerBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                radius: AppSizes.radiusSm,
              ),
              const SizedBox(width: AppSizes.sm),
              const AppShimmerBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                radius: AppSizes.radiusSm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders 5 skeleton tiles inside a scrollable list, mirroring the real
/// category list while [_loading] is true and [_tree] is still empty.
class _CategoryListSkeleton extends StatelessWidget {
  const _CategoryListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg + FloatingAppBar.contentTopInset(context),
        AppSizes.lg,
        AppSizes.fabClearance,
      ),
      itemCount: 5,
      itemBuilder: (_, _) => const _CategoryTileSkeleton(),
    );
  }
}

// ---------------------------------------------------------------------------

/// Single tile in the tree. Recursively renders children inside an
/// AnimatedSize so the expand/collapse animation is consistent.
class _CategoryTreeTile extends StatelessWidget {
  const _CategoryTreeTile({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.onToggle,
    required this.onEdit,
    required this.onAddChild,
    required this.onDelete,
  });

  final CategoryNode node;
  final int depth;
  final Set<int> expanded;
  final ValueChanged<int> onToggle;
  final ValueChanged<Category> onEdit;
  final ValueChanged<int> onAddChild;
  final ValueChanged<Category> onDelete;

  @override
  Widget build(BuildContext context) {
    final c = node.category;
    final isExpanded = expanded.contains(c.id);
    final hasChildren = node.children.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(left: depth * AppSizes.lg, bottom: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: AppColors.surface,
            shape: AppShapes.squircle(
              AppSizes.radiusMd,
              side: BorderSide(color: AppColors.hairline),
            ),
            child: InkWell(
              onTap: () => onEdit(c),
              customBorder: AppShapes.squircle(AppSizes.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.sm),
                child: Row(
                  children: [
                    IconButton(
                      iconSize: AppSizes.iconMd,
                      icon: Icon(
                        hasChildren
                            ? (isExpanded
                                ? Icons.expand_more_rounded
                                : Icons.chevron_right_rounded)
                            : Icons.circle,
                        color: hasChildren ? AppColors.muted : AppColors.disabled,
                      ),
                      onPressed: hasChildren ? () => onToggle(c.id) : null,
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: ShapeDecoration(
                        color: c.isActive
                            ? AppColors.brandSoft
                            : AppColors.surfaceTint,
                        shape: AppShapes.squircle(AppSizes.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        c.iconName != null
                            ? Icons.label_outline
                            : Icons.folder_outlined,
                        size: AppSizes.iconMd,
                        color: c.isActive ? AppColors.brand : AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: c.isActive
                                      ? AppColors.black
                                      : AppColors.muted,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${c.slug ?? '-'}'
                            '${c.productCount != null ? '  ·  ${AppLocalizations.of(context).adminCategoryProductCount('${c.productCount}')}' : ''}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.subtle),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).adminCategoryAddChild,
                      icon: const Icon(Icons.add),
                      onPressed: () => onAddChild(c.id),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context).adminDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(c),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: AppDurations.short,
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSizes.sm),
                    child: Column(
                      children: [
                        for (final child in node.children)
                          _CategoryTreeTile(
                            node: child,
                            depth: depth + 1,
                            expanded: expanded,
                            onToggle: onToggle,
                            onEdit: onEdit,
                            onAddChild: onAddChild,
                            onDelete: onDelete,
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CategoryEditorSheet extends StatefulWidget {
  const _CategoryEditorSheet({
    this.existing,
    this.initialParentId,
    required this.availableParents,
    required this.ds,
  });

  final Category? existing;
  final int? initialParentId;
  final List<Category> availableParents;
  final CategoriesRemoteDataSource ds;

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sortOrder;
  int? _parentId;
  bool _isActive = true;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _parentId = e?.parentId ?? widget.initialParentId;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _imageUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = AppLocalizations.of(context).adminCategoryNameRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.ds.updateCategory(widget.existing!.id, {
          'name': _name.text.trim(),
          if (_description.text.trim().isNotEmpty)
            'description': _description.text.trim(),
          if (_imageUrl.text.trim().isNotEmpty) 'imageUrl': _imageUrl.text.trim(),
          'sortOrder': int.tryParse(_sortOrder.text) ?? 0,
          'isActive': _isActive,
          // Always send parentId — null means re-parent to root.
          'parentId': _parentId,
        });
      } else {
        await widget.ds.createCategory({
          'name': _name.text.trim(),
          if (_description.text.trim().isNotEmpty)
            'description': _description.text.trim(),
          if (_imageUrl.text.trim().isNotEmpty) 'imageUrl': _imageUrl.text.trim(),
          'sortOrder': int.tryParse(_sortOrder.text) ?? 0,
          if (_parentId != null) 'parentId': _parentId,
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSizes.sm),
        Container(
          width: AppSizes.handleWidth,
          height: AppSizes.handleHeight,
          decoration: BoxDecoration(
            color: AppColors.disabled,
            borderRadius: BorderRadius.circular(AppSizes.radiusXs),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                _isEdit ? l10n.adminCategoryEditTitle : l10n.adminCategoryNewTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.huge,
            ),
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.adminCategoryNameLabel,
                  helperText: l10n.adminCategoryNameHelper,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _description,
                decoration: InputDecoration(labelText: l10n.adminCategoryDescriptionLabel),
                maxLines: 2,
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _imageUrl,
                decoration: InputDecoration(
                  labelText: l10n.adminCategoryImageUrlLabel,
                  helperText: l10n.adminCategoryImageUrlHelper,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              DropdownButtonFormField<int?>(
                initialValue: _parentId,
                decoration: InputDecoration(labelText: l10n.adminCategoryParentLabel),
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.adminCategoryRootOption)),
                  for (final c in widget.availableParents)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _sortOrder,
                      decoration: InputDecoration(labelText: l10n.adminSortLabel),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: SwitchListTile.adaptive(
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.adminActive),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.sm),
                Text(
                  _error!,
                  style: TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy ? l10n.adminSaving : (_isEdit ? l10n.adminSaveChanges : l10n.adminCreate),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
