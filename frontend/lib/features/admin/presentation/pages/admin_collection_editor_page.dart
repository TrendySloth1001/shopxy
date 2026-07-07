import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/admin_collection.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_collections_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// Single-page editor for an editorial collection. Two states:
///   * new      — title/slug/etc, can't manage items until saved once
///   * existing — full editor: meta + cover + drag-drop product list
///
/// Item reorder is implemented client-side; on Save we PUT the whole
/// array. Backend replaces atomically in a transaction.
class AdminCollectionEditorPage extends StatefulWidget {
  const AdminCollectionEditorPage({super.key, required this.existingId});
  final int? existingId;

  @override
  State<AdminCollectionEditorPage> createState() =>
      _AdminCollectionEditorPageState();
}

class _AdminCollectionEditorPageState extends State<AdminCollectionEditorPage> {
  AdminCollection? _existing;
  bool _loading = false;
  bool _saving = false;

  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _eyebrow = TextEditingController();
  final _subtitle = TextEditingController();
  final _ctaText = TextEditingController();
  final _ctaTarget = TextEditingController();
  final _bgColor = TextEditingController();
  String? _coverImageUrl;
  bool _isPublished = false;

  final List<AdminCollectionItem> _items = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final loaded =
        await context.read<AdminCollectionsProvider>().getOne(widget.existingId!);
    if (!mounted) return;
    setState(() {
      _existing = loaded;
      if (loaded != null) {
        _title.text = loaded.title;
        _slug.text = loaded.slug;
        _eyebrow.text = loaded.eyebrow ?? '';
        _subtitle.text = loaded.subtitle ?? '';
        _ctaText.text = loaded.ctaText ?? '';
        _ctaTarget.text = loaded.ctaTarget ?? '';
        _bgColor.text = loaded.bgColor ?? '';
        _coverImageUrl = loaded.coverImageUrl;
        _isPublished = loaded.isPublished;
        _items
          ..clear()
          ..addAll(loaded.items);
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _eyebrow.dispose();
    _subtitle.dispose();
    _ctaText.dispose();
    _ctaTarget.dispose();
    _bgColor.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminImageTooLarge),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final shop = context.read<ShopProvider>();
    final url = await shop.uploadImage(file);
    if (!mounted) return;
    setState(() => _saving = false);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(shop.error ?? AppLocalizations.of(context).adminImageUploadFailed)),
      );
      return;
    }
    setState(() => _coverImageUrl = url);
  }

  Map<String, dynamic> _buildMetaBody() {
    return {
      'title': _title.text.trim(),
      if (_slug.text.trim().isNotEmpty) 'slug': _slug.text.trim(),
      'eyebrow': _eyebrow.text.trim().isEmpty ? null : _eyebrow.text.trim(),
      'subtitle': _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
      'ctaText': _ctaText.text.trim().isEmpty ? null : _ctaText.text.trim(),
      'ctaTarget':
          _ctaTarget.text.trim().isEmpty ? null : _ctaTarget.text.trim(),
      'coverImageUrl': _coverImageUrl,
      'bgColor': _bgColor.text.trim().isEmpty ? null : _bgColor.text.trim(),
      'isPublished': _isPublished,
    };
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).adminCollectionTitleRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    final provider = context.read<AdminCollectionsProvider>();
    int? collectionId = _existing?.id;
    if (collectionId == null) {
      final created = await provider.create(_buildMetaBody());
      collectionId = created?.id;
    } else {
      await provider.update(collectionId, _buildMetaBody());
    }
    if (collectionId == null) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? AppLocalizations.of(context).adminSaveFailed)),
      );
      return;
    }
    // Persist item ordering whenever we have items (newly-created
    // collections may legitimately have zero).
    final items = _items
        .asMap()
        .entries
        .map((e) => (productId: e.value.product.id, position: e.key))
        .toList();
    await provider.replaceItems(collectionId, items);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<AdminCollectionProduct>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (_, _) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: const _ProductPickerSheet(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    // De-dupe by product id.
    if (_items.any((it) => it.product.id == picked.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).adminCollectionAlreadyAdded)),
      );
      return;
    }
    setState(() {
      _items.add(
        AdminCollectionItem(id: 0, position: _items.length, product: picked),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppColors.canvas,
        appBar: FloatingAppBar(title: l10n.adminCollectionEditTitle),
        body: const _CollectionEditorSkeleton(),
      );
    }
    final isEdit = _existing != null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: isEdit ? l10n.adminCollectionEditTitle : l10n.adminCollectionNewTitle,
        actions: [
          if (isEdit)
            IconButton(
              tooltip: l10n.adminCollectionAddProduct,
              icon: const Icon(Icons.add),
              onPressed: _addProduct,
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.adminSaving : l10n.adminSave),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.lg + FloatingAppBar.contentTopInset(context),
          AppSizes.lg,
          AppSizes.huge,
        ),
        children: [
          _coverRow(),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l10n.adminCollectionTitleLabel),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _slug,
            decoration: InputDecoration(
              labelText: l10n.adminCollectionSlugLabel,
              helperText: l10n.adminCollectionSlugHelper,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _eyebrow,
            decoration: InputDecoration(
              labelText: l10n.adminCollectionEyebrowLabel,
              helperText: l10n.adminCollectionEyebrowHelper,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _subtitle,
            decoration: InputDecoration(labelText: l10n.adminCollectionSubtitleLabel),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctaText,
                  decoration: InputDecoration(labelText: l10n.adminCollectionCtaTextLabel),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: TextField(
                  controller: _ctaTarget,
                  decoration: InputDecoration(
                    labelText: l10n.adminCollectionCtaTargetLabel,
                    helperText: l10n.adminLinkTargetHelper,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _bgColor,
            decoration: InputDecoration(
              labelText: l10n.adminCollectionBgColorLabel,
              helperText: l10n.adminCollectionBgColorHelper,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          SwitchListTile.adaptive(
            value: _isPublished,
            onChanged: (v) => setState(() => _isPublished = v),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.adminPublished),
            subtitle: Text(l10n.adminCollectionPublishedSubtitle),
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            l10n.adminCollectionItemsSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.sm),
          if (!isEdit)
            _Hint(
              text: l10n.adminCollectionItemsHintNew,
            )
          else if (_items.isEmpty)
            _Hint(
              text: l10n.adminCollectionItemsHintEmpty,
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              onReorder: (oldIdx, newIdx) {
                setState(() {
                  if (newIdx > oldIdx) newIdx -= 1;
                  final row = _items.removeAt(oldIdx);
                  _items.insert(newIdx, row);
                });
              },
              itemBuilder: (_, i) {
                final it = _items[i];
                return _ItemRow(
                  key: ValueKey(it.product.id),
                  item: it,
                  onRemove: () => setState(() => _items.removeAt(i)),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _coverRow() {
    return Row(
      children: [
        Container(
          width: 90,
          height: 60,
          decoration: ShapeDecoration(
            color: AppColors.heroPanel,
            shape: AppShapes.squircle(AppSizes.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: _coverImageUrl == null
              ? Icon(Icons.image_outlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(_coverImageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.upload_outlined),
            label: Text(_coverImageUrl == null
                ? AppLocalizations.of(context).adminCollectionCoverImage
                : AppLocalizations.of(context).adminCollectionReplaceCover),
            onPressed: _saving ? null : _pickCover,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Text(text, style: TextStyle(color: AppColors.muted)),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({super.key, required this.item, required this.onRemove});
  final AdminCollectionItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_handle, color: AppColors.muted),
          const SizedBox(width: AppSizes.sm),
          Container(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            child: item.product.imageUrl == null
                ? Icon(Icons.image_outlined, color: AppColors.muted)
                : Image.network(
                    resolveImageUrl(item.product.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${item.product.sku}${item.product.shopName != null ? '  ·  ${item.product.shopName!}' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: AppSizes.iconMd),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Skeleton that mirrors the collection editor form while data loads.
class _CollectionEditorSkeleton extends StatelessWidget {
  const _CollectionEditorSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg + FloatingAppBar.contentTopInset(context),
        AppSizes.lg,
        AppSizes.huge,
      ),
      children: [
        // Cover row: 90×60 squircle + button placeholder
        Row(
          children: [
            AppShimmerBox(
              width: 90,
              height: 60,
              radius: AppSizes.radiusMd,
            ),
            const SizedBox(width: AppSizes.md),
            const Expanded(
              child: AppShimmerBox(height: 40, radius: AppSizes.radiusMd),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        // Title field
        const _SkeletonField(widthFactor: 0.55),
        const SizedBox(height: AppSizes.md),
        // Slug field
        const _SkeletonField(widthFactor: 0.45),
        const SizedBox(height: AppSizes.md),
        // Eyebrow field
        const _SkeletonField(widthFactor: 0.50),
        const SizedBox(height: AppSizes.md),
        // Subtitle field
        const _SkeletonField(widthFactor: 0.65),
        const SizedBox(height: AppSizes.md),
        // CTA text + CTA target (side-by-side)
        Row(
          children: const [
            Expanded(child: _SkeletonField(widthFactor: 0.7)),
            SizedBox(width: AppSizes.md),
            Expanded(child: _SkeletonField(widthFactor: 0.7)),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        // BG color field
        const _SkeletonField(widthFactor: 0.40),
        const SizedBox(height: AppSizes.lg),
        // Published switch row
        Row(
          children: const [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerLine(widthFactor: 0.30, height: 14),
                  SizedBox(height: 6),
                  AppShimmerLine(widthFactor: 0.55, height: 12),
                ],
              ),
            ),
            SizedBox(width: AppSizes.md),
            AppShimmerBox(width: 48, height: 28, radius: AppSizes.radiusXl),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        // "Items" section label
        const AppShimmerLine(widthFactor: 0.20, height: 16),
        const SizedBox(height: AppSizes.sm),
        // Items hint placeholder
        AppShimmerBox(
          width: double.infinity,
          height: 52,
          radius: AppSizes.radiusMd,
        ),
      ],
    );
  }
}

/// One labelled text-field skeleton: a narrow label line + a full-width input bar.
class _SkeletonField extends StatelessWidget {
  const _SkeletonField({required this.widthFactor});
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmerLine(widthFactor: widthFactor * 0.5, height: 11),
        const SizedBox(height: 6),
        AppShimmerLine(widthFactor: widthFactor, height: 18),
        const SizedBox(height: 4),
        const AppShimmerLine(widthFactor: 1.0, height: 1),
      ],
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();
  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _controller = TextEditingController();
  List<AdminCollectionProduct> _results = [];
  Timer? _debounce;
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppDurations.searchDebounce, () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final hits = await context.read<AdminCollectionsProvider>().searchProducts(value);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _results = hits;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.handleWidth,
          height: AppSizes.handleHeight,
          margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.hairline,
            borderRadius: BorderRadius.circular(AppSizes.radiusXs),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.adminCollectionProductSearchLabel,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: _onChanged,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    l10n.adminCollectionProductSearchHint,
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.sm,
                    AppSizes.lg,
                    AppSizes.huge,
                  ),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(p),
                      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: ShapeDecoration(
                          color: AppColors.surface,
                          shape: AppShapes.squircle(AppSizes.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: AppSizes.avatarSm,
                              height: AppSizes.avatarSm,
                              clipBehavior: Clip.antiAlias,
                              decoration: ShapeDecoration(
                                color: AppColors.heroPanel,
                                shape: AppShapes.squircle(AppSizes.radiusSm),
                              ),
                              child: p.imageUrl == null
                                  ? Icon(Icons.image_outlined,
                                      color: AppColors.muted)
                                  : Image.network(
                                      resolveImageUrl(p.imageUrl!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.broken_image_outlined),
                                    ),
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    '${p.sku}${p.shopName != null ? '  ·  ${p.shopName!}' : ''}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
