import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CategoriesProvider>().loadCategories();
    });
  }

  void _showAddEditDialog([Category? category]) {
    final nameController = TextEditingController(text: category?.name ?? '');
    final descController = TextEditingController(
      text: category?.description ?? '',
    );
    final isEditing = category != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEditing ? AppStrings.editCategory : AppStrings.addCategory,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.categoryName,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: AppStrings.description,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final provider = context.read<CategoriesProvider>();
              if (isEditing) {
                await provider.updateCategory(
                  category.id,
                  name: name,
                  description: descController.text.trim(),
                );
              } else {
                await provider.createCategory(
                  name: name,
                  description: descController.text.trim().isNotEmpty
                      ? descController.text.trim()
                      : null,
                );
              }

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text('Products in this category will be uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<CategoriesProvider>().deleteCategory(category.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.categoryDeleted)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CategoriesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navCategories)),
      body: provider.isLoading && provider.categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.categories.isEmpty
          ? EmptyState(
              icon: Icons.category_outlined,
              title: AppStrings.noCategories,
              subtitle: AppStrings.noCategoriesHint,
            )
          : RefreshIndicator(
              onRefresh: () => provider.loadCategories(),
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSizes.lg),
                itemCount: provider.categories.length,
                itemBuilder: (context, index) {
                  final cat = provider.categories[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.sm),
                    decoration: ShapeDecoration(
                      color: theme.cardTheme.color,
                      shape: AppShapes.squircle(
                        AppSizes.radiusMd,
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: ShapeDecoration(
                          color: theme.colorScheme.tertiaryContainer.withValues(
                            alpha: 0.5,
                          ),
                          shape: AppShapes.squircle(AppSizes.radiusSm),
                        ),
                        child: Icon(
                          Icons.category_rounded,
                          color: theme.colorScheme.tertiary,
                          size: AppSizes.iconMd,
                        ),
                      ),
                      title: Text(
                        cat.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: cat.description != null
                          ? Text(
                              cat.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cat.productCount != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.sm,
                                vertical: 2,
                              ),
                              decoration: ShapeDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                shape: AppShapes.squircle(AppSizes.radiusFull),
                              ),
                              child: Text(
                                '${cat.productCount}',
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text(AppStrings.edit),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(AppStrings.delete),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') _showAddEditDialog(cat);
                              if (value == 'delete') _deleteCategory(cat);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'categories_fab',
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
