import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/pages/category_products_page.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

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
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          0,
          AppSizes.lg,
          AppSizes.lg,
        ),
        actions: [
          AppButton.ghost(
            label: AppStrings.cancel,
            onPressed: () => Navigator.pop(ctx),
          ),
          AppButton.primary(
            label: AppStrings.save,
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
          ),
        ],
      ),
    );
  }

  void _deleteCategory(Category category) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Delete "${category.name}"?',
      message: 'Products in this category will be uncategorized.',
      confirmLabel: AppStrings.delete,
      danger: true,
    );

    if (confirmed && mounted) {
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
    final provider = context.watch<CategoriesProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navCategories)),
      body: provider.isLoading && provider.categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.categories.isEmpty
              ? EmptyState.line(
                  kind: LineArt.productTag,
                  title: AppStrings.noCategories,
                  subtitle: AppStrings.noCategoriesHint,
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadCategories(),
                  color: AppColors.black,
                  backgroundColor: AppColors.white,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                    itemCount: provider.categories.length,
                    separatorBuilder: (_, _) => const AppDivider(),
                    itemBuilder: (context, index) {
                      final cat = provider.categories[index];
                      return _CategoryTile(
                        category: cat,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryProductsPage(category: cat),
                          ),
                        ),
                        onEdit: () => _showAddEditDialog(cat),
                        onDelete: () => _deleteCategory(cat),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              const AppIconAvatar.outlined(icon: Icons.category_rounded),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (category.description != null)
                      Text(
                        category.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (category.productCount != null) ...[
                const SizedBox(width: AppSizes.sm),
                AppStatusBadge(label: '${category.productCount}', dense: true),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.muted),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text(AppStrings.edit)),
                  PopupMenuItem(value: 'delete', child: Text(AppStrings.delete)),
                ],
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
