import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_banner_editor_sheet.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_banners_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class AdminBannersPage extends StatefulWidget {
  const AdminBannersPage({super.key});

  @override
  State<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends State<AdminBannersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AdminBannersProvider>().load();
    });
  }

  Future<void> _openEditor({AdminBanner? existing}) async {
    final changed = await AdminBannerEditorSheet.show(context, existing: existing);
    if (changed == true && mounted) {
      await context.read<AdminBannersProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminBannersProvider>();
    final grouped = provider.grouped;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Banner manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New banner'),
      ),
      body: provider.isLoading && provider.banners.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.banners.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Text(provider.error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      for (final entry in grouped.entries)
                        _PlacementSection(
                          placement: entry.key,
                          banners: entry.value,
                          onTapBanner: (b) => _openEditor(existing: b),
                          onAdd: () => _openEditor(),
                          onDelete: (b) async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete banner?'),
                                content: Text(
                                  '"${b.title}" will be removed from ${b.placement.label}.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.errorSoft,
                                      foregroundColor: AppColors.error,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && context.mounted) {
                              await context
                                  .read<AdminBannersProvider>()
                                  .delete(b.id);
                            }
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _PlacementSection extends StatelessWidget {
  const _PlacementSection({
    required this.placement,
    required this.banners,
    required this.onTapBanner,
    required this.onAdd,
    required this.onDelete,
  });
  final BannerPlacement placement;
  final List<AdminBanner> banners;
  final ValueChanged<AdminBanner> onTapBanner;
  final VoidCallback onAdd;
  final ValueChanged<AdminBanner> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                placement.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(width: AppSizes.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 2,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.surfaceTint,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                child: Text(
                  '${banners.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          if (banners.isEmpty)
            _EmptyTile(onAdd: onAdd)
          else
            ...banners.map(
              (b) => _BannerTile(
                banner: b,
                onTap: () => onTapBanner(b),
                onDelete: () => onDelete(b),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: AppColors.surfaceTint,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(
              color: AppColors.hairline,
              style: BorderStyle.solid,
            ),
          ),
        ),
        child: Row(
          children: const [
            Icon(Icons.add_photo_alternate_outlined, color: AppColors.muted),
            SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                'No banners in this placement yet',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({
    required this.banner,
    required this.onTap,
    required this.onDelete,
  });
  final AdminBanner banner;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String get _status {
    final now = DateTime.now();
    if (!banner.isActive) return 'Off';
    if (banner.startAt != null && banner.startAt!.isAfter(now)) return 'Scheduled';
    if (banner.endAt != null && banner.endAt!.isBefore(now)) return 'Expired';
    return 'Live';
  }

  Color get _statusColor {
    switch (_status) {
      case 'Live':
        return AppColors.brand;
      case 'Scheduled':
        return AppColors.info;
      case 'Expired':
        return AppColors.warning;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 56,
                  decoration: ShapeDecoration(
                    color: AppColors.heroPanel,
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    resolveImageUrl(banner.imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: 2,
                            ),
                            decoration: ShapeDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              shape: AppShapes.squircle(AppSizes.radiusFull),
                            ),
                            child: Text(
                              _status,
                              style: TextStyle(
                                color: _statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Text(
                            'Sort ${banner.sortOrder}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                          ),
                          if (banner.startAt != null || banner.endAt != null) ...[
                            const SizedBox(width: AppSizes.sm),
                            Text(
                              _windowLabel(banner),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.muted,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _windowLabel(AdminBanner b) {
    final df = DateFormat.MMMd();
    if (b.startAt != null && b.endAt != null) {
      return '${df.format(b.startAt!)} – ${df.format(b.endAt!)}';
    }
    if (b.startAt != null) return 'from ${df.format(b.startAt!)}';
    if (b.endAt != null) return 'until ${df.format(b.endAt!)}';
    return '';
  }
}
