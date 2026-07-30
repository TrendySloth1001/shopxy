import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/admin_collection.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_collection_editor_page.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_collections_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Index of all editorial collections (curated product lists). Tap a
/// row to open the editor — that's where meta, cover, and items get
/// managed in one place.
class AdminCollectionsPage extends StatefulWidget {
  const AdminCollectionsPage({super.key});

  @override
  State<AdminCollectionsPage> createState() => _AdminCollectionsPageState();
}

class _AdminCollectionsPageState extends State<AdminCollectionsPage> {
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminCollectionsProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  Future<void> _openExisting(String id) async {
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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.adminCollectionDeleteTitle),
        content: Text(l10n.adminCollectionDeleteBody(c.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.adminCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.adminDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AdminCollectionsProvider>().delete(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AdminCollectionsProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.adminCollectionsTitle,
        actions: [
          IconButton(
            tooltip: l10n.adminRefresh,
            icon: const AppIcon(AppIcons.refresh),
            onPressed: provider.isLoading ? null : () => provider.load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNew,
        icon: const AppIcon(AppIcons.add),
        label: Text(l10n.adminCollectionNew),
      ),
      body: provider.isLoading && provider.list.isEmpty
          ? const _CollectionsListSkeleton()
          : RefreshIndicator(
              onRefresh: provider.load,
              child: provider.list.isEmpty
                  ? ListView(
                      padding: EdgeInsets.only(
                        top: FloatingAppBar.contentTopInset(context),
                      ),
                      children: [
                        const SizedBox(height: AppSizes.huge),
                        Center(child: Text(l10n.adminCollectionsEmpty)),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.fromLTRB(
                        AppSizes.lg,
                        AppSizes.lg + FloatingAppBar.contentTopInset(context),
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
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.surface,
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
                  ? AppIcon(
                      AppIcons.collectionsBookmark,
                      color: AppColors.muted,
                    )
                  : Image.network(
                      resolveImageUrl(collection.coverImageUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const AppIcon(AppIcons.brokenImageOutlined),
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
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    '/${collection.slug}  ·  '
                    '${collection.itemCount == 1 ? l10n.adminCollectionItemCountOne('${collection.itemCount}') : l10n.adminCollectionItemCountOther('${collection.itemCount}')}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            _StatusChip(published: collection.isPublished),
            IconButton(
              icon: const AppIcon(AppIcons.deleteOutline),
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
        published
            ? AppLocalizations.of(context).adminPublished
            : AppLocalizations.of(context).adminDraft,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: published ? AppColors.success : AppColors.black,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets — shown while provider.isLoading && list.isEmpty
// ---------------------------------------------------------------------------

class _CollectionsListSkeleton extends StatelessWidget {
  const _CollectionsListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg + FloatingAppBar.contentTopInset(context),
        AppSizes.lg,
        AppSizes.fabClearance,
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
      itemBuilder: (_, _) => const _CollectionRowSkeleton(),
    );
  }
}

class _CollectionRowSkeleton extends StatelessWidget {
  const _CollectionRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          // Cover image placeholder
          AppShimmerBox(width: 60, height: 60, radius: AppSizes.radiusMd),
          const SizedBox(width: AppSizes.md),
          // Title + subtitle lines
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.6, height: 14),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.4, height: 11),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Status chip placeholder
          AppShimmerBox(width: 58, height: 24, radius: AppSizes.radiusSm),
          // Delete icon space
          const SizedBox(width: AppSizes.lg + AppSizes.md),
        ],
      ),
    );
  }
}
