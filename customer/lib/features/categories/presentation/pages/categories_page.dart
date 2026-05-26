import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/category_detail_page.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/categories/presentation/widgets/category_image.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Customer landing for "All categories". Big image grid; tap drills
/// down into a [CategoryDetailPage] that lists subcategories + the
/// merged product feed for the whole parent bucket.
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
      context.read<CategoriesProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoriesProvider>();
    final tree = provider.tree;

    return Scaffold(
      appBar: AppBar(title: const Text('All categories')),
      body: provider.isLoading && tree.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : tree.isEmpty
              ? const Center(child: Text('No categories yet'))
              : RefreshIndicator(
                  onRefresh: () => provider.load(force: true),
                  color: AppColors.black,
                  backgroundColor: AppColors.white,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: tree.length,
                    itemBuilder: (context, index) {
                      final node = tree[index];
                      return _CategoryTile(
                        category: node.category,
                        childCount: node.children.length,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryDetailPage(node: node),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.childCount,
    required this.onTap,
  });
  final Category category;
  final int childCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CategoryImage(category: category),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (childCount > 0)
            Text(
              '$childCount subcategories',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}
