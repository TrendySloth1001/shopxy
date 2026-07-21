import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_banner_editor_sheet.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_banners_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

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
    final changed = await AdminBannerEditorSheet.show(
      context,
      existing: existing,
    );
    if (changed == true && mounted) {
      await context.read<AdminBannersProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<AdminBannersProvider>();
    final grouped = provider.grouped;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.adminBannersTitle,
        actions: [
          IconButton(
            tooltip: l10n.adminRefresh,
            icon: const AppIcon(AppIcons.refresh),
            onPressed: provider.isLoading ? null : () => provider.load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const AppIcon(AppIcons.add),
        label: Text(l10n.adminBannerNew),
      ),
      body: provider.isLoading && provider.banners.isEmpty
          ? const _BannersSkeleton()
          : provider.error != null && provider.banners.isEmpty
          ? SafeArea(
              top: true,
              bottom: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.xl),
                  child: Text(provider.error!, textAlign: TextAlign.center),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                padding: EdgeInsets.only(
                  top: FloatingAppBar.contentTopInset(context),
                  bottom: AppSizes.huge,
                ),
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
                            title: Text(l10n.adminBannerDeleteTitle),
                            content: Text(
                              l10n.adminBannerDeleteBody(b.placement.label),
                            ),
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
                        if (confirm == true && context.mounted) {
                          await context.read<AdminBannersProvider>().delete(
                            b.id,
                          );
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
                style: Theme.of(context).textTheme.titleMedium?.extraBold,
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
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
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
          children: [
            AppIcon(AppIcons.addPhotoAlternateOutlined, color: AppColors.muted),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                AppLocalizations.of(context).adminBannerPlacementEmpty,
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
    if (banner.startAt != null && banner.startAt!.isAfter(now)) {
      return 'Scheduled';
    }
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
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline),
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
                    errorBuilder: (_, _, _) => AppIcon(
                      AppIcons.brokenImageOutlined,
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
                        banner.linkUrl?.isNotEmpty == true
                            ? banner.linkUrl!
                            : banner.placement.label,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSizes.xxs),
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
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: _statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).adminBannerSort('${banner.sortOrder}'),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          if (banner.startAt != null ||
                              banner.endAt != null) ...[
                            const SizedBox(width: AppSizes.sm),
                            Text(
                              _windowLabel(banner),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).adminDelete,
                  icon: const AppIcon(AppIcons.deleteOutline),
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

// ---------------------------------------------------------------------------
// Skeleton widgets (shown while isLoading && banners.isEmpty)
// ---------------------------------------------------------------------------

class _BannersSkeleton extends StatelessWidget {
  const _BannersSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: FloatingAppBar.contentTopInset(context),
        bottom: AppSizes.huge,
      ),
      children: const [
        _PlacementSectionSkeleton(tileCount: 3),
        _PlacementSectionSkeleton(tileCount: 2),
        _PlacementSectionSkeleton(tileCount: 2),
      ],
    );
  }
}

class _PlacementSectionSkeleton extends StatelessWidget {
  const _PlacementSectionSkeleton({required this.tileCount});
  final int tileCount;

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
          // Section header: label shimmer line + badge shimmer box
          Row(
            children: const [
              AppShimmerLine(widthFactor: 0.35, height: 16),
              SizedBox(width: AppSizes.sm),
              AppShimmerBox(width: 28, height: 20, radius: AppSizes.radiusSm),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          for (int i = 0; i < tileCount; i++) const _BannerTileSkeleton(),
        ],
      ),
    );
  }
}

class _BannerTileSkeleton extends StatelessWidget {
  const _BannerTileSkeleton();

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
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              // Image placeholder
              AppShimmerBox(width: 72, height: 56, radius: AppSizes.radiusSm),
              const SizedBox(width: AppSizes.md),
              // Text lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmerLine(widthFactor: 0.65, height: 14),
                    SizedBox(height: AppSizes.xs),
                    AppShimmerLine(widthFactor: 0.45, height: 11),
                  ],
                ),
              ),
              // Delete icon placeholder
              const AppShimmerBox(
                width: 32,
                height: 32,
                radius: AppSizes.radiusFull,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
