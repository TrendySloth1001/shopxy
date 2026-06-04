import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/models/banner_product.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';
import 'package:shopxy/features/carousel/presentation/providers/carousels_provider.dart';
import 'package:shopxy/features/carousel/presentation/widgets/color_canvas.dart';
import 'package:shopxy/features/carousel/presentation/widgets/hero_slide_preview.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Full-page slide editor. The merchant picks one of the 7 templated
/// card layouts, fills the matching copy fields, uploads an image, and
/// tunes the colour palette via the ColorCanvas. A live preview at the
/// top reflects every keystroke.
class SlideEditorPage extends StatefulWidget {
  const SlideEditorPage({
    super.key,
    required this.carouselId,
    this.existing,
  });
  final int carouselId;
  final CarouselSlide? existing;

  @override
  State<SlideEditorPage> createState() => _SlideEditorPageState();
}

class _SlideEditorPageState extends State<SlideEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _eyebrow;
  late final TextEditingController _ctaText;
  late final TextEditingController _brandLabel;
  late final TextEditingController _bgColor;
  late final TextEditingController _accentColor;
  late final TextEditingController _sortOrder;
  String? _imageUrl;
  String? _brandImageUrl;
  BannerImageFit _brandImageFit = BannerImageFit.cover;
  BannerTemplate _template = BannerTemplate.classic;
  BannerImageFit _imageFit = BannerImageFit.cover;
  bool _isActive = true;

  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _subtitle = TextEditingController(text: e?.subtitle ?? '');
    _eyebrow = TextEditingController(text: e?.eyebrow ?? '');
    _ctaText = TextEditingController(text: e?.ctaText ?? '');
    _brandLabel = TextEditingController(text: e?.brandLabel ?? '');
    _bgColor = TextEditingController(text: e?.bgColor ?? '#EFE4D6');
    _accentColor = TextEditingController(text: e?.accentColor ?? '#B23A2E');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _imageUrl = e?.imageUrl;
    _brandImageUrl = e?.brandImageUrl;
    _brandImageFit = e?.brandImageFit ?? BannerImageFit.cover;
    _template = e?.template ?? BannerTemplate.classic;
    _imageFit = e?.imageFit ?? BannerImageFit.cover;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _eyebrow.dispose();
    _ctaText.dispose();
    _brandLabel.dispose();
    _bgColor.dispose();
    _accentColor.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  // ── Image upload ────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final url = await _uploadFromGallery(maxWidth: 1600);
    if (url == null) return;
    setState(() => _imageUrl = url);
  }

  /// Upload a brand logo. Smaller maxWidth than the main image since a
  /// brand mark is rendered into a chip; ~512 px is plenty and keeps
  /// the wire payload small.
  Future<void> _pickBrandImage() async {
    final url = await _uploadFromGallery(maxWidth: 512);
    if (url == null) return;
    setState(() => _brandImageUrl = url);
  }

  Future<String?> _uploadFromGallery({required int maxWidth}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth.toDouble(),
    );
    if (picked == null || !mounted) return null;
    final file = File(picked.path);
    if (!_validateImageSize(file)) return null;
    setState(() => _busy = true);
    final shop = context.read<ShopProvider>();
    final url = await shop.uploadImage(file);
    if (!mounted) return null;
    setState(() => _busy = false);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shop.error ?? 'Image upload failed')),
      );
      return null;
    }
    return url;
  }

  /// 5 MB ceiling per slide image — Sharp re-encode + 3 MinIO PUTs on
  /// the upload path is the real cost, but rejecting early on the
  /// device side avoids a wasted network round-trip on slow links.
  bool _validateImageSize(File file) {
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image is larger than 5 MB. Pick a smaller image or crop tighter.',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Color _parseColor(String hex, {Color fallback = AppColors.heroPanel}) {
    final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
    if (m == null) return fallback;
    var raw = m.group(1)!;
    if (raw.length == 6) raw = 'FF$raw';
    return Color(int.parse(raw, radix: 16));
  }

  // ── Save ────────────────────────────────────────────────────────────

  /// Decodes the backend's error envelope into a one-line snackbar.
  /// Prefer the human `message` over the machine-readable `code` so
  /// the merchant sees something actionable; dev-mode 500s now ship
  /// the underlying error message as `details`, which gets shown too.
  String _formatError(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return raw;
    try {
      final body = jsonDecode(raw.substring(start)) as Map<String, dynamic>;
      final details = body['details'];
      if (details is List && details.isNotEmpty) {
        return details
            .map((d) {
              final m = d as Map<String, dynamic>;
              final path = (m['path'] ?? '').toString();
              final msg = (m['message'] ?? '').toString();
              return path.isEmpty ? msg : '$path: $msg';
            })
            .join(' • ');
      }
      final message = body['message'];
      final code = body['error'] ?? body['code'];
      if (message is String && code is String && code != message) {
        return '$message ($code)';
      }
      if (message is String) return message;
      if (code is String) return code;
    } catch (_) {
      // fall through to raw
    }
    return raw;
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title + image are required')),
      );
      return;
    }
    setState(() => _busy = true);

    final body = <String, dynamic>{
      'template': _template.wire,
      'imageFit': _imageFit.wire,
      'title': _title.text.trim(),
      if (_subtitle.text.trim().isNotEmpty) 'subtitle': _subtitle.text.trim(),
      if (_eyebrow.text.trim().isNotEmpty) 'eyebrow': _eyebrow.text.trim(),
      if (_ctaText.text.trim().isNotEmpty) 'ctaText': _ctaText.text.trim(),
      if (_brandLabel.text.trim().isNotEmpty)
        'brandLabel': _brandLabel.text.trim(),
      if (_brandImageUrl != null) 'brandImageUrl': _brandImageUrl,
      'brandImageFit': _brandImageFit.wire,
      'imageUrl': _imageUrl,
      'bgColor': _bgColor.text.trim(),
      if (_accentColor.text.trim().isNotEmpty)
        'accentColor': _accentColor.text.trim(),
      'sortOrder': int.tryParse(_sortOrder.text) ?? 0,
      'isActive': _isActive,
    };

    final provider = context.read<CarouselsProvider>();
    final result = _isEdit
        ? await provider.updateSlide(widget.carouselId, widget.existing!.id, body)
        : await provider.createSlide(widget.carouselId, body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatError(provider.error ?? 'Save failed'))),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete slide?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final success = await context
        .read<CarouselsProvider>()
        .deleteSlide(widget.carouselId, e.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<CarouselsProvider>().error ?? 'Delete failed',
          ),
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit slide' : 'New slide'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _confirmDelete,
            ),
          TextButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          _PreviewHeader(
            template: _template,
            title: _title.text.isEmpty ? 'Your slide title' : _title.text,
            subtitle: _subtitle.text.isEmpty ? null : _subtitle.text,
            eyebrow: _eyebrow.text.isEmpty ? null : _eyebrow.text,
            brandLabel: _brandLabel.text.isEmpty ? null : _brandLabel.text,
            brandImageUrl: _brandImageUrl,
            brandImageFit: _brandImageFit,
            ctaText: _ctaText.text.isEmpty ? null : _ctaText.text,
            imageUrl: _imageUrl,
            imageFit: _imageFit,
            bgColor: _parseColor(_bgColor.text),
            accent: _parseColor(_accentColor.text, fallback: AppColors.black),
          ),
          Expanded(
            child: _TemplatedTab(
              template: _template,
              onTemplate: (t) => setState(() => _template = t),
              imageFit: _imageFit,
              onImageFit: (f) => setState(() => _imageFit = f),
              imageUrl: _imageUrl,
              onPickImage: _busy ? null : _pickImage,
              brandImageUrl: _brandImageUrl,
              brandImageFit: _brandImageFit,
              onPickBrandImage: _busy ? null : _pickBrandImage,
              onBrandImageFit: (f) => setState(() => _brandImageFit = f),
              onClearBrandImage: () => setState(() => _brandImageUrl = null),
              title: _title,
              subtitle: _subtitle,
              eyebrow: _eyebrow,
              ctaText: _ctaText,
              brandLabel: _brandLabel,
              bgColor: _bgColor,
              accentColor: _accentColor,
              sortOrder: _sortOrder,
              isActive: _isActive,
              onActiveChanged: (v) => setState(() => _isActive = v),
              parseColor: _parseColor,
              onAnyChange: () => setState(() {}),
              slideId: widget.existing?.id,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Preview header ────────────────────────────────────────────────────

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.template,
    required this.title,
    required this.imageFit,
    required this.bgColor,
    required this.accent,
    required this.brandImageFit,
    this.subtitle,
    this.eyebrow,
    this.brandLabel,
    this.brandImageUrl,
    this.ctaText,
    this.imageUrl,
  });
  final BannerTemplate template;
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? brandLabel;
  final String? brandImageUrl;
  final BannerImageFit brandImageFit;
  final String? ctaText;
  final String? imageUrl;
  final BannerImageFit imageFit;
  final Color bgColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: HeroSlidePreview(
        data: HeroSlidePreviewData(
          template: template,
          imageFit: imageFit,
          title: title,
          subtitle: subtitle,
          eyebrow: eyebrow,
          brandLabel: brandLabel,
          brandImageUrl: brandImageUrl,
          brandImageFit: brandImageFit,
          ctaText: ctaText,
          imageUrl: imageUrl,
          bgColor: bgColor,
          accent: accent,
        ),
      ),
    );
  }
}

// ── Templated form body ───────────────────────────────────────────────

class _TemplatedTab extends StatelessWidget {
  const _TemplatedTab({
    required this.template,
    required this.onTemplate,
    required this.imageFit,
    required this.onImageFit,
    required this.imageUrl,
    required this.onPickImage,
    required this.brandImageUrl,
    required this.brandImageFit,
    required this.onPickBrandImage,
    required this.onBrandImageFit,
    required this.onClearBrandImage,
    required this.title,
    required this.subtitle,
    required this.eyebrow,
    required this.ctaText,
    required this.brandLabel,
    required this.bgColor,
    required this.accentColor,
    required this.sortOrder,
    required this.isActive,
    required this.onActiveChanged,
    required this.parseColor,
    required this.onAnyChange,
    required this.slideId,
  });

  final int? slideId;

  final BannerTemplate template;
  final ValueChanged<BannerTemplate> onTemplate;
  final BannerImageFit imageFit;
  final ValueChanged<BannerImageFit> onImageFit;
  final String? imageUrl;
  final VoidCallback? onPickImage;

  final String? brandImageUrl;
  final BannerImageFit brandImageFit;
  final VoidCallback? onPickBrandImage;
  final ValueChanged<BannerImageFit> onBrandImageFit;
  final VoidCallback onClearBrandImage;

  final TextEditingController title;
  final TextEditingController subtitle;
  final TextEditingController eyebrow;
  final TextEditingController ctaText;
  final TextEditingController brandLabel;
  final TextEditingController bgColor;
  final TextEditingController accentColor;
  final TextEditingController sortOrder;

  final bool isActive;
  final ValueChanged<bool> onActiveChanged;

  final Color Function(String hex, {Color fallback}) parseColor;
  final VoidCallback onAnyChange;

  @override
  Widget build(BuildContext context) {
    final supportsText = template.supportsTextFields;
    final supportsSubtitle = template.supportsSubtitle;
    final supportsColors = template.supportsColors;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.huge,
      ),
      children: [
        _SectionCard(
          title: 'Slide design',
          subtitle: 'Pick a layout — controls below adapt to what the '
              'chosen template can show.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TemplateStrip(template: template, onTemplate: onTemplate),
              const SizedBox(height: AppSizes.sm),
              Text(
                template.description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        _SectionCard(
          title: 'Background image',
          subtitle: 'JPG / PNG / WebP up to 5 MB. Fill crops; Fit '
              'letterboxes onto the background colour.',
          child: _ImageRow(
            imageUrl: imageUrl,
            imageFit: imageFit,
            onPick: onPickImage,
            onImageFit: onImageFit,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        // Brand block: logo + label live together since they render in
        // the same chip on the templated card. Either alone or both.
        _SectionCard(
          title: 'Brand',
          subtitle: 'Logo and label render together on the slide '
              'chip when both are set.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BrandImageRow(
                imageUrl: brandImageUrl,
                imageFit: brandImageFit,
                onPick: onPickBrandImage,
                onImageFit: onBrandImageFit,
                onClear: brandImageUrl == null ? null : onClearBrandImage,
              ),
              if (supportsText) ...[
                const SizedBox(height: AppSizes.md),
                _CountedField(
                  controller: brandLabel,
                  label: 'Brand label',
                  hint: 'e.g. SPRING ARRIVALS',
                  maxLength: 40,
                  onChanged: onAnyChange,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        if (supportsText)
          _SectionCard(
            title: 'Copy',
            subtitle: supportsSubtitle
                ? 'Title is required. Eyebrow + subtitle render when the '
                    'template supports them.'
                : 'Title is required. Eyebrow renders when set.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CountedField(
                  controller: title,
                  label: 'Title',
                  required: true,
                  maxLength: 120,
                  onChanged: onAnyChange,
                ),
                if (supportsSubtitle) ...[
                  const SizedBox(height: AppSizes.md),
                  _CountedField(
                    controller: subtitle,
                    label: 'Subtitle',
                    maxLength: 240,
                    maxLines: 2,
                    onChanged: onAnyChange,
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                _CountedField(
                  controller: eyebrow,
                  label: 'Eyebrow',
                  hint: 'Tiny copy above the title',
                  maxLength: 60,
                  onChanged: onAnyChange,
                ),
                const SizedBox(height: AppSizes.md),
                _CountedField(
                  controller: ctaText,
                  label: 'Button label',
                  hint: 'e.g. Shop the deal — defaults to "Shop now"',
                  maxLength: 40,
                  onChanged: onAnyChange,
                ),
              ],
            ),
          ),
        if (supportsText) const SizedBox(height: AppSizes.md),
        if (supportsColors)
          _SectionCard(
            title: 'Colours',
            subtitle: 'Tap a swatch on the picker to update the hex '
                'field, or type a hex value directly.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _HexField(
                        controller: bgColor,
                        label: 'Background',
                        parseColor: parseColor,
                        onChanged: onAnyChange,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: _HexField(
                        controller: accentColor,
                        label: 'Accent',
                        parseColor: parseColor,
                        onChanged: onAnyChange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                ColorCanvas(
                  bg: parseColor(bgColor.text),
                  accent:
                      parseColor(accentColor.text, fallback: AppColors.black),
                  onChanged: (target, hex) {
                    if (target == 'bg') {
                      bgColor.text = hex;
                    } else {
                      accentColor.text = hex;
                    }
                    onAnyChange();
                  },
                ),
              ],
            ),
          ),
        if (supportsColors) const SizedBox(height: AppSizes.md),
        _SectionCard(
          title: 'Display',
          subtitle: 'Lower sort numbers appear first inside the carousel.',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  controller: sortOrder,
                  decoration: const InputDecoration(labelText: 'Sort'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: SwitchListTile.adaptive(
                  value: isActive,
                  onChanged: onActiveChanged,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text(
                    'Off → slide is hidden, even if the carousel is live.',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        _SectionCard(
          title: 'Discounted products',
          subtitle: 'Pin products to this slide with a discount. The '
              'discount auto-fills onto matching invoice lines, so you '
              'never have to remember to apply it twice.',
          child: _DiscountedProductsSection(slideId: slideId),
        ),
      ],
    );
  }
}

// ── Building blocks ───────────────────────────────────────────────────

class _TemplateStrip extends StatelessWidget {
  const _TemplateStrip({required this.template, required this.onTemplate});
  final BannerTemplate template;
  final ValueChanged<BannerTemplate> onTemplate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: BannerTemplate.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
        itemBuilder: (_, i) {
          final t = BannerTemplate.values[i];
          final selected = t == template;
          return InkWell(
            onTap: () => onTemplate(t),
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
            child: Container(
              width: 96,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.sm,
              ),
              decoration: ShapeDecoration(
                color: selected
                    ? AppColors.brand.withValues(alpha: 0.12)
                    : AppColors.surfaceTint,
                shape: AppShapes.squircle(
                  AppSizes.radiusMd,
                  side: BorderSide(
                    color: selected ? AppColors.brand : AppColors.hairline,
                    width: selected ? 1.5 : 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: AppSizes.iconMd,
                    color: selected ? AppColors.brand : AppColors.muted,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.brand : AppColors.black,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({
    required this.imageUrl,
    required this.imageFit,
    required this.onPick,
    required this.onImageFit,
  });
  final String? imageUrl;
  final BannerImageFit imageFit;
  final VoidCallback? onPick;
  final ValueChanged<BannerImageFit> onImageFit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 90,
          height: 60,
          decoration: ShapeDecoration(
            color: AppColors.heroPanel,
            shape: AppShapes.squircle(AppSizes.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl == null
              ? const Icon(Icons.image_outlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(imageUrl!),
                  fit: imageFit == BannerImageFit.contain
                      ? BoxFit.contain
                      : BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload_outlined),
                label: Text(imageUrl == null ? 'Upload image' : 'Replace image'),
              ),
              const SizedBox(height: AppSizes.sm),
              SegmentedButton<BannerImageFit>(
                segments: const [
                  ButtonSegment(
                    value: BannerImageFit.cover,
                    label: Text('Fill'),
                    icon: Icon(Icons.crop_landscape),
                  ),
                  ButtonSegment(
                    value: BannerImageFit.contain,
                    label: Text('Fit'),
                    icon: Icon(Icons.fit_screen_outlined),
                  ),
                ],
                selected: {imageFit},
                onSelectionChanged: (s) => onImageFit(s.first),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Brand-logo upload + edit controls. Visually similar to `_ImageRow`
/// but with a square thumbnail (logos are usually icon-shaped) and a
/// Clear button to remove the upload entirely.
class _BrandImageRow extends StatelessWidget {
  const _BrandImageRow({
    required this.imageUrl,
    required this.imageFit,
    required this.onPick,
    required this.onImageFit,
    required this.onClear,
  });
  final String? imageUrl;
  final BannerImageFit imageFit;
  final VoidCallback? onPick;
  final ValueChanged<BannerImageFit> onImageFit;
  /// Null hides the Clear button — the merchant hasn't uploaded yet,
  /// so there's nothing to remove.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppSizes.massive,
          height: AppSizes.massive,
          decoration: ShapeDecoration(
            color: AppColors.heroPanel,
            shape: AppShapes.squircle(AppSizes.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: imageUrl == null
              ? const Icon(Icons.business_outlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(imageUrl!),
                  fit: imageFit == BannerImageFit.contain
                      ? BoxFit.contain
                      : BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPick,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        imageUrl == null ? 'Upload logo' : 'Replace logo',
                      ),
                    ),
                  ),
                  if (onClear != null) ...[
                    const SizedBox(width: AppSizes.sm),
                    IconButton(
                      tooltip: 'Remove logo',
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_outline),
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              SegmentedButton<BannerImageFit>(
                segments: const [
                  ButtonSegment(
                    value: BannerImageFit.cover,
                    label: Text('Fill'),
                    icon: Icon(Icons.crop_landscape),
                  ),
                  ButtonSegment(
                    value: BannerImageFit.contain,
                    label: Text('Fit'),
                    icon: Icon(Icons.fit_screen_outlined),
                  ),
                ],
                selected: {imageFit},
                onSelectionChanged: (s) => onImageFit(s.first),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Visual container for one logical section of the editor form.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.3,
                    ),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// TextField + character counter that recolours as the merchant
/// approaches / exceeds the cap. Hides Flutter's default muted
/// counter so the visible one is the only one.
class _CountedField extends StatefulWidget {
  const _CountedField({
    required this.controller,
    required this.label,
    required this.maxLength,
    required this.onChanged,
    this.hint,
    this.required = false,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLength;
  final bool required;
  final int maxLines;
  final VoidCallback onChanged;

  @override
  State<_CountedField> createState() => _CountedFieldState();
}

class _CountedFieldState extends State<_CountedField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.controller.text.characters.length;
    final near = length > widget.maxLength * 0.9;
    final over = length > widget.maxLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          decoration: InputDecoration(
            labelText:
                widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hint,
            counterText: '',
          ),
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: AppSizes.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$length / ${widget.maxLength}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: over
                        ? AppColors.error
                        : near
                            ? AppColors.warning
                            : AppColors.muted,
                    fontWeight: over ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Hex color input with a live swatch preview and inline error when
/// the value isn't parseable. Saves a round-trip — the merchant sees
/// invalid hex immediately instead of after a Save → 400.
class _HexField extends StatefulWidget {
  const _HexField({
    required this.controller,
    required this.label,
    required this.parseColor,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final Color Function(String hex, {Color fallback}) parseColor;
  final VoidCallback onChanged;

  @override
  State<_HexField> createState() => _HexFieldState();
}

class _HexFieldState extends State<_HexField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  static final _hexRe = RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  @override
  Widget build(BuildContext context) {
    final raw = widget.controller.text.trim();
    final valid = _hexRe.hasMatch(raw);
    final swatch = valid
        ? widget.parseColor(raw, fallback: AppColors.heroPanel)
        : AppColors.surfaceTint;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              labelText: '${widget.label} (#hex)',
              errorText: raw.isEmpty || valid ? null : 'Invalid hex',
            ),
            onChanged: (_) => widget.onChanged(),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Container(
          width: AppSizes.iconXl,
          height: AppSizes.iconXl,
          decoration: BoxDecoration(
            color: swatch,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.hairline, width: 1),
          ),
        ),
      ],
    );
  }
}

// ── Discounted products section ───────────────────────────────────────
//
// The merchant pins shop products to this slide and gives each a
// discount. The discount auto-fills onto matching invoice lines on the
// backend (invoices.service.resolveInvoiceFields), so the merchant
// never has to remember to type it twice.
//
// State design:
//   - Owns a working list of BannerProductLink for this slide.
//   - Loads on init when slideId != null; persists via the carousel
//     provider's saveSlideProducts (uncached round-trip).
//   - Discount edits are kept in the working list and round-tripped on
//     "Save discounts" — typing a value should not fire a network call
//     per keystroke.
//
// Why this lives in slide_editor_page.dart and not its own file:
//   It's a leaf widget that only the slide editor uses, with no public
//   API surface. Splitting would create a one-import dependency that
//   obscures the editor's surface area; keep it inline.

class _DiscountedProductsSection extends StatefulWidget {
  const _DiscountedProductsSection({required this.slideId});
  final int? slideId;

  @override
  State<_DiscountedProductsSection> createState() =>
      _DiscountedProductsSectionState();
}

class _DiscountedProductsSectionState
    extends State<_DiscountedProductsSection> {
  List<BannerProductLink> _items = const [];
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.slideId != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await context
          .read<CarouselsProvider>()
          .fetchSlideProducts(widget.slideId!);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await context
          .read<CarouselsProvider>()
          .saveSlideProducts(widget.slideId!, _items);
      if (!mounted) return;
      if (saved != null) {
        setState(() {
          _items = saved;
          _dirty = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discounts saved')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save failed — try again')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ProductPickerSheet(),
    );
    if (picked == null || !mounted) return;
    if (_items.any((it) => it.productId == picked.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already added to this slide')),
      );
      return;
    }
    setState(() {
      _items = [
        ..._items,
        BannerProductLink(
          productId: picked.id,
          name: picked.name,
          sku: picked.sku,
          mrp: picked.mrp,
          sellingPrice: picked.sellingPrice,
          imageUrl: picked.images.isNotEmpty ? picked.images.first.url : '',
          discountType: BannerProductDiscountType.percent,
          discountValue: 0,
          position: _items.length,
        ),
      ];
      _dirty = true;
    });
  }

  void _updateItem(int index, BannerProductLink next) {
    setState(() {
      _items = [
        ..._items.sublist(0, index),
        next,
        ..._items.sublist(index + 1),
      ];
      _dirty = true;
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items = [
        ..._items.sublist(0, index),
        ..._items.sublist(index + 1),
      ];
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slideId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Text(
          'Save the slide first, then come back to pin discounted products.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.error),
            ),
          ),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Text(
              'No products yet. Tap "Add product" to pin one with a discount.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < _items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.sm),
                  child: _DiscountRow(
                    item: _items[i],
                    onChanged: (next) => _updateItem(i, next),
                    onRemove: () => _removeItem(i),
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSizes.sm),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: (_saving || !_dirty) ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save discounts'),
            ),
          ],
        ),
      ],
    );
  }
}

class _DiscountRow extends StatefulWidget {
  const _DiscountRow({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });
  final BannerProductLink item;
  final ValueChanged<BannerProductLink> onChanged;
  final VoidCallback onRemove;

  @override
  State<_DiscountRow> createState() => _DiscountRowState();
}

class _DiscountRowState extends State<_DiscountRow> {
  late TextEditingController _value;

  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: _format(widget.item.discountValue));
  }

  @override
  void didUpdateWidget(covariant _DiscountRow old) {
    super.didUpdateWidget(old);
    // External replacement (e.g. type switch) syncs the field — but
    // never on the merchant's mid-keystroke updates, which we already
    // round-tripped through onChanged.
    if (old.item.productId != widget.item.productId) {
      _value.text = _format(widget.item.discountValue);
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  static String _format(double v) {
    if (v == 0) return '';
    // Drop trailing .0 so "20" doesn't render as "20.0" in the field.
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  /// Clamp the raw text input to the per-mode safe range. Mirrors the
  /// server-side clamp in promo-pricing.ts so the merchant sees the
  /// same effective ceiling client-side and server-side.
  double _clamp(String raw) {
    final n = double.tryParse(raw.trim());
    if (n == null || !n.isFinite || n <= 0) return 0;
    if (widget.item.discountType == BannerProductDiscountType.percent) {
      return n > 90 ? 90 : n;
    }
    final ceiling = widget.item.sellingPrice > 0.01
        ? widget.item.sellingPrice - 0.01
        : 0.0;
    return n > ceiling ? ceiling : n;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isPct = item.discountType == BannerProductDiscountType.percent;
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.hairline),
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(url: item.imageUrl),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'MRP ₹${item.sellingPrice.toStringAsFixed(2)}'
                  '  →  Sale ₹${item.salePrice.toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.xs),
                Row(
                  children: [
                    SegmentedButton<BannerProductDiscountType>(
                      segments: const [
                        ButtonSegment(
                          value: BannerProductDiscountType.percent,
                          label: Text('%'),
                        ),
                        ButtonSegment(
                          value: BannerProductDiscountType.amount,
                          label: Text('₹'),
                        ),
                      ],
                      selected: {item.discountType},
                      onSelectionChanged: (sel) {
                        final next = sel.first;
                        // Re-clamp on type change so a 95 in PERCENT
                        // mode doesn't survive a switch to AMOUNT and
                        // overflow the new ceiling.
                        final reclamped = _DiscountRowState._reclamp(
                          next,
                          item.discountValue,
                          item.sellingPrice,
                        );
                        _value.text = _DiscountRowState._format(reclamped);
                        widget.onChanged(
                          item.copyWith(
                            discountType: next,
                            discountValue: reclamped,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: AppSizes.sm),
                    SizedBox(
                      width: 88,
                      child: TextField(
                        controller: _value,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: isPct ? '0–90' : '0–${item.sellingPrice.toStringAsFixed(0)}',
                        ),
                        onChanged: (raw) {
                          final clamped = _clamp(raw);
                          widget.onChanged(
                            item.copyWith(discountValue: clamped),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: AppSizes.iconMd),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }

  /// Re-clamp the value when the merchant flips type. Static so the
  /// onSelectionChanged closure can call it without capturing `this`.
  static double _reclamp(
    BannerProductDiscountType type,
    double current,
    double sellingPrice,
  ) {
    if (current <= 0) return 0;
    if (type == BannerProductDiscountType.percent) {
      return current > 90 ? 90 : current;
    }
    final ceiling = sellingPrice > 0.01 ? sellingPrice - 0.01 : 0.0;
    return current > ceiling ? ceiling : current;
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: AppSizes.productThumbSize, height: AppSizes.productThumbSize,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
          border: Border.all(color: AppColors.hairline),
        ),
        child: const Icon(
          Icons.image_outlined,
          size: AppSizes.iconMd,
          color: AppColors.muted,
        ),
      );
    }
    return ClipRRect(
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
      child: Image.network(
        resolveImageUrl(url),
        width: AppSizes.productThumbSize,
        height: AppSizes.productThumbSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: AppSizes.productThumbSize, height: AppSizes.productThumbSize,
          color: AppColors.canvas,
          child: const Icon(Icons.broken_image_outlined,
              size: AppSizes.iconMd, color: AppColors.muted),
        ),
      ),
    );
  }
}

// ── Product picker bottom sheet ──────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();
  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _q = TextEditingController();
  List<Product> _results = const [];
  bool _loading = true;
  // Most-recent-query token: ignore stale responses if the merchant
  // typed something newer mid-flight.
  int _lastQueryId = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final id = ++_lastQueryId;
    setState(() => _loading = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final res = await ds.getProducts(search: q.isEmpty ? null : q, limit: 30);
      if (!mounted || id != _lastQueryId) return;
      setState(() {
        _results = res.products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _lastQueryId) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: TextField(
                controller: _q,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search your products',
                ),
                onChanged: _search,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'No matches',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.muted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final p = _results[i];
                            return ListTile(
                              leading: _Thumb(
                                url: p.images.isNotEmpty
                                    ? p.images.first.url
                                    : '',
                              ),
                              title: Text(p.name, maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${p.sku} · ₹${p.sellingPrice.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              onTap: () => Navigator.of(context).pop(p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
