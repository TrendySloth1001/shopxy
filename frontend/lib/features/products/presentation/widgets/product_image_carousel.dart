import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/widgets/product_thumbnail.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Image carousel for the product detail hero.
///
/// Three independent concerns sharing one widget:
///   * `PageView` paginates through every image (no images → falls
///     back to the same hash-tinted monogram the list uses, so the
///     hero never looks broken).
///   * Dot indicator under the carousel for fast position read-out.
///   * Thumbnail strip beneath that for jump-to navigation when there
///     are 3+ images.
///
/// Tapping any image opens a full-screen viewer with pinch-zoom and
/// horizontal swipe between images.
class ProductImageCarousel extends StatefulWidget {
  const ProductImageCarousel({
    super.key,
    required this.product,
    this.onAddPhotos,
  });

  final Product product;

  /// When the product has no images and this is non-null, the empty
  /// monogram band becomes a tappable "Add photos" affordance (wired to
  /// the edit page) so the placeholder isn't a dead end. Null hides the
  /// call-to-action — e.g. for roles that can't edit products.
  final VoidCallback? onAddPhotos;

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jumpTo(int i) {
    _pageController.animateToPage(
      i,
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openLightbox(int startIndex) async {
    if (widget.product.images.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ProductLightbox(
          urls: widget.product.images.map((e) => e.url).toList(),
          startIndex: startIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.images;

    // No images: show the monogram band, same look as before. No
    // dot strip, no thumbnail rail — nothing to navigate. When the
    // viewer can edit, the band turns into an "Add photos" call-to-
    // action so the placeholder isn't a dead end.
    if (images.isEmpty) {
      final band = Container(
        width: double.infinity,
        height: 220,
        color: AppColors.heroPanel,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProductThumbnail(product: widget.product, size: 112),
            if (widget.onAddPhotos != null) ...[
              const SizedBox(height: AppSizes.md),
              _AddPhotosPill(onTap: widget.onAddPhotos!),
            ],
          ],
        ),
      );
      return band;
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 260,
          color: AppColors.heroPanel,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () => _openLightbox(i),
                child: Hero(
                  tag: 'product-image-${widget.product.id}-$i',
                  child: CachedNetworkImage(
                    imageUrl: resolveImageUrl(images[i].url),
                    fit: BoxFit.contain,
                    placeholder: (_, _) => Container(
                      color: AppColors.heroPanel,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: AppSizes.iconLg,
                        height: AppSizes.iconLg,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, _, _) => Center(
                      child: ProductThumbnail(
                        product: widget.product,
                        size: 128,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: AppSizes.sm),
          _DotIndicator(count: images.length, active: _index),
        ],
        if (images.length > 1) ...[
          const SizedBox(height: AppSizes.sm),
          _ThumbnailStrip(
            urls: images.map((e) => e.url).toList(),
            active: _index,
            onTap: _jumpTo,
          ),
          const SizedBox(height: AppSizes.xs),
        ],
      ],
    );
  }
}

/// "Add photos" call-to-action shown over the empty monogram band when
/// the viewer can edit the product. Tapping it opens the edit page where
/// the image manager lives.
class _AddPhotosPill extends StatelessWidget {
  const _AddPhotosPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                AppIcons.addAPhotoOutlined,
                size: AppSizes.iconSm,
                color: AppColors.black,
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                l10n.productsAddPhotos,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppDurations.short,
            width: i == active ? AppSizes.iconSm : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: i == active ? AppColors.black : AppColors.hairline,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.urls,
    required this.active,
    required this.onTap,
  });

  final List<String> urls;
  final int active;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.avatarMd,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (context, i) {
          final isActive = i == active;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: AppDurations.short,
              width: AppSizes.avatarMd,
              height: AppSizes.avatarMd,
              decoration: ShapeDecoration(
                color: AppColors.surface,
                shape: AppShapes.squircle(
                  AppSizes.radiusSm,
                  side: BorderSide(
                    color: isActive ? AppColors.black : AppColors.hairline,
                    width: isActive ? 2 : 1,
                  ),
                ),
              ),
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                child: CachedNetworkImage(
                  imageUrl: resolveImageUrl(urls[i]),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: AppColors.heroPanel,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.heroPanel,
                    child: AppIcon(
                      AppIcons.imageNotSupportedOutlined,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-screen image viewer. One PageView, one InteractiveViewer per
/// page (so pinch-zoom doesn't fight the swipe gesture — zoom is
/// scoped to its own page). Tap closes; swipe between images.
class _ProductLightbox extends StatefulWidget {
  const _ProductLightbox({required this.urls, required this.startIndex});

  final List<String> urls;
  final int startIndex;

  @override
  State<_ProductLightbox> createState() => _ProductLightboxState();
}

class _ProductLightboxState extends State<_ProductLightbox> {
  late final PageController _controller = PageController(
    initialPage: widget.startIndex,
  );
  late int _index = widget.startIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A fullscreen photo viewer is a media surface: it stays black with light
    // controls in every theme (like any gallery lightbox), so it uses fixed
    // Material black/white rather than theme-flipping tokens.
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: FloatingAppBar(
        titleWidget: Text(
          '${_index + 1} / ${widget.urls.length}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: resolveImageUrl(widget.urls[i]),
                fit: BoxFit.contain,
                placeholder: (_, _) => const SizedBox(
                  width: AppSizes.iconLg,
                  height: AppSizes.iconLg,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                errorWidget: (_, _, _) => const AppIcon(
                  AppIcons.imageNotSupportedOutlined,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
