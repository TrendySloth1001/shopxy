import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/admin_collection.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_collection_editor_page.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_collections_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Index of all editorial collections (curated product lists). Tap a
/// row to open the editor — that's where meta, cover, and items get
/// managed in one place.
class AdminCollectionsPage extends StatefulWidget {
  const AdminCollectionsPage({super.key});

  @override
  State<AdminCollectionsPage> createState() => _AdminCollectionsPageState();
}

class _AdminCollectionsPageState extends State<AdminCollectionsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminCollectionsProvider>().load();
    });
  }

  Future<void> _openNew() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AdminCollectionEditorPage(existingId: null),
      ),
    );
    if (changed == true && mounted) {
      await context.read<AdminCollectionsProvider>().load();
    }
  }

  Future<void> _openExisting(int id) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminCollectionEditorPage(existingId: id),
      ),
    );
    if (changed == true && mounted) {
      await context.read<AdminCollectionsProvider>().load();
    }
  }

  Future<void> _confirmDelete(AdminCollectionSummary c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text('"${c.title}" and its item list will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AdminCollectionsProvider>().delete(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminCollectionsProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Collections'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const Icon(Icons.add),
        label: const Text('New collection'),
      ),
      body: provider.isLoading && provider.list.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: provider.load,
              child: provider.list.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: AppSizes.huge),
                        Center(child: Text('No collections yet')),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.lg,
                        AppSizes.lg,
                        AppSizes.lg,
                        AppSizes.fabClearance,
                      ),
                      itemCount: provider.list.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSizes.md),
                      itemBuilder: (_, i) {
                        final c = provider.list[i];
                        return _CollectionRow(
                          collection: c,
                          onTap: () => _openExisting(c.id),
                          onDelete: () => _confirmDelete(c),
                        );
                      },
                    ),
            ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  const _CollectionRow({
    required this.collection,
    required this.onTap,
    required this.onDelete,
  });
  final AdminCollectionSummary collection;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(AppSizes.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusMd),
              ),
              child: collection.coverImageUrl == null
                  ? const Icon(Icons.collections_bookmark, color: AppColors.muted)
                  : Image.network(
                      resolveImageUrl(collection.coverImageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '/${collection.slug}  ·  ${collection.itemCount} items',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            _StatusChip(published: collection.isPublished),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.published});
  final bool published;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: published ? AppColors.successSoft : AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Text(
        published ? 'Published' : 'Draft',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: published ? AppColors.success : AppColors.black,
            ),
      ),
    );
  }
}
