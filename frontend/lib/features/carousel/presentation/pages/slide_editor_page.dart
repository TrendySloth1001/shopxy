import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';
import 'package:shopxy/features/carousel/presentation/providers/carousels_provider.dart';
import 'package:shopxy/features/carousel/presentation/widgets/color_canvas.dart';
import 'package:shopxy/features/carousel/presentation/widgets/hero_slide_preview.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Full-page slide editor. Replaces the bottom-sheet editor entirely
/// for new carousels — far more vertical room means the live preview
/// can sit at the top while the merchant edits, and the freeform
/// canvas (Phase 4) needs every pixel it can get.
///
/// Two modes selected via the tab bar at the top:
///   * Templated — pick one of the 7 `HeroSlidePreview` cards, fill
///     the existing fields (title/subtitle/eyebrow/etc.) and colour
///     pickers (`ColorCanvas`). Phase 3 deliverable.
///   * Freeform — drag-position text blocks on a canvas, transform
///     the image. Phase 4 — a placeholder note ships in Phase 3 so
///     the tab bar already shows the future surface.
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

class _SlideEditorPageState extends State<SlideEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Common metadata + Templated-mode fields.
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _eyebrow;
  late final TextEditingController _ctaText;
  late final TextEditingController _brandLabel;
  late final TextEditingController _bgColor;
  late final TextEditingController _accentColor;
  late final TextEditingController _sortOrder;
  String? _imageUrl;
  BannerTemplate _template = BannerTemplate.classic;
  BannerImageFit _imageFit = BannerImageFit.cover;
  bool _isActive = true;
  CarouselSlideMode _mode = CarouselSlideMode.templated;

  // Freeform-mode state (kept here so flipping tabs preserves edits).
  // Real editing UI ships in Phase 4; Phase 3 only keeps the existing
  // payload if the merchant is editing a freeform slide.
  List<CarouselSlideTextBlock> _textBlocks = const [];
  CarouselSlideImageTransform _imageTransform =
      CarouselSlideImageTransform.identity;

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
    _template = e?.template ?? BannerTemplate.classic;
    _imageFit = e?.imageFit ?? BannerImageFit.cover;
    _isActive = e?.isActive ?? true;
    _mode = e?.mode ?? CarouselSlideMode.templated;
    _textBlocks = e?.textBlocks ?? const [];
    _imageTransform = e?.imageTransform ?? CarouselSlideImageTransform.identity;

    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: _mode == CarouselSlideMode.freeform ? 1 : 0,
    );
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      setState(() {
        _mode = _tab.index == 1
            ? CarouselSlideMode.freeform
            : CarouselSlideMode.templated;
      });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
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
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    if (!_validateImageSize(file)) return;
    setState(() => _busy = true);
    final shop = context.read<ShopProvider>();
    final url = await shop.uploadImage(file);
    if (!mounted) return;
    setState(() => _busy = false);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shop.error ?? 'Image upload failed')),
      );
      return;
    }
    setState(() => _imageUrl = url);
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

  // ── Colour helpers (shared with ColorCanvas + HeroSlidePreview) ─────

  Color _parseColor(String hex, {Color fallback = AppColors.heroPanel}) {
    final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
    if (m == null) return fallback;
    var raw = m.group(1)!;
    if (raw.length == 6) raw = 'FF$raw';
    return Color(int.parse(raw, radix: 16));
  }

  // ── Save ────────────────────────────────────────────────────────────

  /// Decodes the backend's zod error shape into a one-line snackbar.
  /// Same helper shape as the legacy bottom-sheet editor — kept inline
  /// rather than extracted because both surfaces will be deleted /
  /// rewritten before any third caller emerges.
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
      if (body['error'] is String) return body['error'] as String;
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
      'mode': _mode.wire,
      'template': _template.wire,
      'imageFit': _imageFit.wire,
      'title': _title.text.trim(),
      if (_subtitle.text.trim().isNotEmpty) 'subtitle': _subtitle.text.trim(),
      if (_eyebrow.text.trim().isNotEmpty) 'eyebrow': _eyebrow.text.trim(),
      if (_ctaText.text.trim().isNotEmpty) 'ctaText': _ctaText.text.trim(),
      if (_brandLabel.text.trim().isNotEmpty)
        'brandLabel': _brandLabel.text.trim(),
      'imageUrl': _imageUrl,
      'bgColor': _bgColor.text.trim(),
      if (_accentColor.text.trim().isNotEmpty)
        'accentColor': _accentColor.text.trim(),
      'sortOrder': int.tryParse(_sortOrder.text) ?? 0,
      'isActive': _isActive,
      // Freeform payload only ships when the slide is FREEFORM. Keeps
      // the wire small for the common templated case and avoids
      // creating empty-blocks rows on the server.
      if (_mode == CarouselSlideMode.freeform)
        'textBlocks': _textBlocks.map((b) => b.toJson()).toList(),
      if (_mode == CarouselSlideMode.freeform)
        'imageTransform': _imageTransform.toJson(),
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
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_customize_outlined), text: 'Templated'),
            Tab(icon: Icon(Icons.draw_outlined), text: 'Freeform'),
          ],
        ),
      ),
      body: Column(
        children: [
          _PreviewHeader(
            template: _template,
            title: _title.text.isEmpty ? 'Your slide title' : _title.text,
            subtitle: _subtitle.text.isEmpty ? null : _subtitle.text,
            brandLabel: _brandLabel.text.isEmpty ? null : _brandLabel.text,
            ctaText: _ctaText.text.isEmpty ? null : _ctaText.text,
            imageUrl: _imageUrl,
            imageFit: _imageFit,
            bgColor: _parseColor(_bgColor.text),
            accent: _parseColor(_accentColor.text, fallback: AppColors.black),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _TemplatedTab(
                  template: _template,
                  onTemplate: (t) => setState(() => _template = t),
                  imageFit: _imageFit,
                  onImageFit: (f) => setState(() => _imageFit = f),
                  imageUrl: _imageUrl,
                  onPickImage: _busy ? null : _pickImage,
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
                ),
                const _FreeformComingSoon(),
              ],
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
    this.subtitle,
    this.brandLabel,
    this.ctaText,
    this.imageUrl,
  });
  final BannerTemplate template;
  final String title;
  final String? subtitle;
  final String? brandLabel;
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
          brandLabel: brandLabel,
          ctaText: ctaText,
          imageUrl: imageUrl,
          bgColor: bgColor,
          accent: accent,
        ),
      ),
    );
  }
}

// ── Templated tab body ────────────────────────────────────────────────

class _TemplatedTab extends StatelessWidget {
  const _TemplatedTab({
    required this.template,
    required this.onTemplate,
    required this.imageFit,
    required this.onImageFit,
    required this.imageUrl,
    required this.onPickImage,
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
  });

  final BannerTemplate template;
  final ValueChanged<BannerTemplate> onTemplate;
  final BannerImageFit imageFit;
  final ValueChanged<BannerImageFit> onImageFit;
  final String? imageUrl;
  final VoidCallback? onPickImage;

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
        _SectionLabel(text: 'Slide design'),
        const SizedBox(height: AppSizes.sm),
        _TemplateStrip(template: template, onTemplate: onTemplate),
        const SizedBox(height: AppSizes.sm),
        Text(
          template.description,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: AppSizes.lg),
        _SectionLabel(text: 'Image'),
        const SizedBox(height: AppSizes.sm),
        _ImageRow(
          imageUrl: imageUrl,
          imageFit: imageFit,
          onPick: onPickImage,
          onImageFit: onImageFit,
        ),
        const SizedBox(height: AppSizes.lg),
        if (supportsText) ...[
          _SectionLabel(text: 'Copy'),
          const SizedBox(height: AppSizes.sm),
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Title *'),
            onChanged: (_) => onAnyChange(),
          ),
          const SizedBox(height: AppSizes.md),
          if (supportsSubtitle) ...[
            TextField(
              controller: subtitle,
              decoration: const InputDecoration(labelText: 'Subtitle'),
              onChanged: (_) => onAnyChange(),
            ),
            const SizedBox(height: AppSizes.md),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: eyebrow,
                  decoration: const InputDecoration(
                    labelText: 'Eyebrow',
                    helperText: 'Tiny copy above the title',
                  ),
                  onChanged: (_) => onAnyChange(),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: TextField(
                  controller: brandLabel,
                  decoration: const InputDecoration(labelText: 'Brand label'),
                  onChanged: (_) => onAnyChange(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: ctaText,
            decoration: const InputDecoration(
              labelText: 'Button label',
              hintText: 'e.g. Shop the deal',
            ),
            onChanged: (_) => onAnyChange(),
          ),
          const SizedBox(height: AppSizes.lg),
        ],
        if (supportsColors) ...[
          _SectionLabel(text: 'Colours'),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: bgColor,
                  decoration:
                      const InputDecoration(labelText: 'BG color (#hex)'),
                  onChanged: (_) => onAnyChange(),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: TextField(
                  controller: accentColor,
                  decoration: const InputDecoration(labelText: 'Accent (#hex)'),
                  onChanged: (_) => onAnyChange(),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          ColorCanvas(
            bg: parseColor(bgColor.text),
            accent: parseColor(accentColor.text, fallback: AppColors.black),
            onChanged: (target, hex) {
              if (target == 'bg') {
                bgColor.text = hex;
              } else {
                accentColor.text = hex;
              }
              onAnyChange();
            },
          ),
          const SizedBox(height: AppSizes.lg),
        ],
        _SectionLabel(text: 'Display'),
        const SizedBox(height: AppSizes.sm),
        Row(
          children: [
            SizedBox(
              width: 90,
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
                  'When off, the slide is hidden regardless of carousel '
                  'schedule.',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Building blocks ───────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.muted,
        ),
      );
}

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
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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
                    size: 20,
                    color: selected ? AppColors.brand : AppColors.muted,
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
                  imageUrl!,
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

class _FreeformComingSoon extends StatelessWidget {
  const _FreeformComingSoon();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.draw_outlined,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            const Text(
              'Freeform canvas — coming next',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Drag-position text blocks anywhere on the slide, with image '
              'transforms (fit, fill, crop, rotate, filters). Ships in the '
              'next phase. Save now to keep this slide as a templated one '
              'and switch to freeform later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
