import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/presentation/pages/merchant_carousel_editor_sheet.dart';
import 'package:shopxy/features/carousel/presentation/providers/merchant_carousel_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Merchant-facing list of carousel slides. Loads /me/banners on first
/// build; every slide here is HERO-placement and scoped to the
/// caller's shop, so what's shown on this page is exactly what will
/// surface (subject to schedule + active flags) on the customer
/// home-screen hero carousel.
class MyCarouselPage extends StatefulWidget {
  const MyCarouselPage({super.key});

  @override
  State<MyCarouselPage> createState() => _MyCarouselPageState();
}

class _MyCarouselPageState extends State<MyCarouselPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MerchantCarouselProvider>().load();
    });
  }

  Future<void> _openEditor({AdminBanner? existing}) async {
    final changed = await MerchantCarouselEditorSheet.show(
      context,
      existing: existing,
    );
    if (changed == true && mounted) {
      await context.read<MerchantCarouselProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MerchantCarouselProvider>();
    final slides = provider.slides;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('My carousel'),
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
        label: const Text('New slide'),
      ),
      body: provider.isLoading && slides.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && slides.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Text(provider.error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: provider.load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSizes.lg,
                      AppSizes.lg,
                      AppSizes.lg,
                      96,
                    ),
                    children: [
                      const _HeaderCallout(),
                      const SizedBox(height: AppSizes.lg),
                      if (slides.isEmpty)
                        _EmptyState(onAdd: () => _openEditor())
                      else
                        ...slides.map(
                          (s) => _SlideTile(
                            slide: s,
                            onTap: () => _openEditor(existing: s),
                            onDelete: () => _confirmDelete(s),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _confirmDelete(AdminBanner b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete slide?'),
        content: Text('"${b.title}" will be removed from your carousel.'),
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
    if (confirm == true && mounted) {
      await context.read<MerchantCarouselProvider>().delete(b.id);
    }
  }
}

class _HeaderCallout extends StatelessWidget {
  const _HeaderCallout();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.view_carousel_outlined, color: AppColors.brandStrong),
          SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              'Slides here are visible on the customer home screen hero carousel. '
              'Schedule a window or toggle "Active" off to hide a slide without deleting it.',
              style: TextStyle(color: AppColors.brandStrong, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.xl),
        decoration: ShapeDecoration(
          color: AppColors.surfaceTint,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          children: const [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 48,
              color: AppColors.muted,
            ),
            SizedBox(height: AppSizes.sm),
            Text(
              'No slides yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
            SizedBox(height: AppSizes.xs),
            Text(
              'Tap "New slide" to publish your first hero carousel banner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideTile extends StatelessWidget {
  const _SlideTile({
    required this.slide,
    required this.onTap,
    required this.onDelete,
  });
  final AdminBanner slide;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String get _status {
    final now = DateTime.now();
    if (!slide.isActive) return 'Off';
    if (slide.startAt != null && slide.startAt!.isAfter(now)) return 'Scheduled';
    if (slide.endAt != null && slide.endAt!.isBefore(now)) return 'Expired';
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
                    resolveImageUrl(slide.imageUrl),
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
                        slide.title,
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
                            'Sort ${slide.sortOrder}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                          if (slide.startAt != null || slide.endAt != null) ...[
                            const SizedBox(width: AppSizes.sm),
                            Text(
                              _windowLabel(slide),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.muted),
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
