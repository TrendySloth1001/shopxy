import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';

/// Modal bottom sheet for creating or editing a category.
///
/// Hosts the name + description fields and the icon grid so the picker
/// is colocated with the form — picking a new icon updates the preview
/// avatar at the top of the sheet without leaving the screen.
class CategoryFormSheet extends StatefulWidget {
  const CategoryFormSheet({super.key, this.category});

  final Category? category;

  static Future<void> show(BuildContext context, {Category? category}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CategoryFormSheet(category: category),
    );
  }

  @override
  State<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<CategoryFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String? _selectedIcon;
  bool _saving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descController = TextEditingController(
      text: widget.category?.description ?? '',
    );
    _selectedIcon = widget.category?.iconName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final provider = context.read<CategoriesProvider>();
    final desc = _descController.text.trim();
    try {
      if (_isEditing) {
        // "Cleared icon" needs explicit signalling so we can send null —
        // a no-op `iconName` would otherwise leave the prior value intact.
        final cleared =
            widget.category!.iconName != null && _selectedIcon == null;
        await provider.updateCategory(
          widget.category!.id,
          name: name,
          description: desc,
          iconName: _selectedIcon,
          clearIcon: cleared,
        );
      } else {
        await provider.createCategory(
          name: name,
          description: desc.isNotEmpty ? desc : null,
          iconName: _selectedIcon,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSizes.md),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      resolveCategoryIcon(_selectedIcon),
                      size: 28,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? AppStrings.editCategory
                          : AppStrings.addCategory,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: AppStrings.categoryName,
                ),
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: AppStrings.description,
                ),
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Text(
                    'Icon',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedIcon != null)
                    TextButton(
                      onPressed: () => setState(() => _selectedIcon = null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                          vertical: 0,
                        ),
                        minimumSize: const Size(0, 32),
                        foregroundColor: AppColors.muted,
                      ),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              _IconGrid(
                selected: _selectedIcon,
                onSelect: (n) => setState(() => _selectedIcon = n),
              ),
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton.ghost(
                      label: AppStrings.cancel,
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: AppButton.primary(
                      label: AppStrings.save,
                      isLoading: _saving,
                      onPressed: _saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: AppSizes.sm,
          crossAxisSpacing: AppSizes.sm,
          childAspectRatio: 0.85,
        ),
        itemCount: kCategoryIconOptions.length,
        itemBuilder: (context, index) {
          final opt = kCategoryIconOptions[index];
          final isSelected = opt.name == selected;
          return _IconTile(
            option: opt,
            isSelected: isSelected,
            onTap: () => onSelect(opt.name),
          );
        },
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final CategoryIconOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.black : AppColors.hairline,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              option.icon,
              size: 24,
              color: isSelected ? AppColors.white : AppColors.black,
            ),
            const SizedBox(height: 4),
            Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: isSelected ? AppColors.white : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
