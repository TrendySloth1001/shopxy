import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/models/banner_product.dart';
import 'package:shopxy/features/carousel/presentation/pages/merchant_product_picker_page.dart';
import 'package:shopxy/features/carousel/presentation/providers/merchant_carousel_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Modal editor for one carousel slide. The slide is always HERO
/// placement and scoped to the caller's shop; tapping it on the
/// customer side opens a dedicated slide-detail page rendered from
/// the linked products + per-row discounts captured here. There is
/// no free-form CTA-target field — the linked product list is the
/// tap target by design.
class MerchantCarouselEditorSheet extends StatefulWidget {
  const MerchantCarouselEditorSheet({super.key, this.existing});
  final AdminBanner? existing;

  static Future<bool?> show(BuildContext context, {AdminBanner? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.95,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: MerchantCarouselEditorSheet(existing: existing),
        ),
      ),
    );
  }

  @override
  State<MerchantCarouselEditorSheet> createState() =>
      _MerchantCarouselEditorSheetState();
}

class _MerchantCarouselEditorSheetState
    extends State<MerchantCarouselEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _eyebrow;
  late final TextEditingController _ctaText;
  late final TextEditingController _brandLabel;
  late final TextEditingController _bgColor;
  late final TextEditingController _accentColor;
  late final TextEditingController _sortOrder;
  String? _imageUrl;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isActive = true;
  bool _busy = false;

  /// Working copy of the slide's linked-product list — mutated locally
  /// (add / remove / reorder / discount change) and replaced on the
  /// server in a single PUT when the merchant saves.
  List<BannerProductLink> _linkedProducts = const [];
  bool _loadingLinks = false;

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
    _startAt = e?.startAt;
    _endAt = e?.endAt;
    _isActive = e?.isActive ?? true;

    if (e != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLinks(e.id));
    }
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

  Future<void> _loadLinks(int bannerId) async {
    if (!mounted) return;
    setState(() => _loadingLinks = true);
    try {
      final items = await context
          .read<MerchantCarouselProvider>()
          .loadLinkedProducts(bannerId);
      if (!mounted) return;
      setState(() => _linkedProducts = items);
    } catch (_) {
      // Silent on load failure — the merchant can still edit hero copy
      // and re-pick products; the empty list defaults to "no links".
    } finally {
      if (mounted) setState(() => _loadingLinks = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final url = await context.read<ShopProvider>().uploadImage(File(picked.path));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (url != null) _imageUrl = url;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final t = time ?? const TimeOfDay(hour: 0, minute: 0);
    final combined =
        DateTime(date.year, date.month, date.day, t.hour, t.minute);
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  Color _parseColor(String hex, {Color fallback = AppColors.heroPanel}) {
    final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
    if (m == null) return fallback;
    var raw = m.group(1)!;
    if (raw.length == 6) raw = 'FF$raw';
    return Color(int.parse(raw, radix: 16));
  }

  /// Decodes the backend's `{ error, details:[{path,message},…] }` zod
  /// response into a single readable line so the snackbar points at the
  /// offending field. Falls back to the raw string when the body
  /// isn't shaped like a Zod error.
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

  Future<void> _openProductPicker() async {
    final added = await MerchantProductPickerPage.show(
      context,
      alreadySelected: _linkedProducts.map((l) => l.productId).toSet(),
    );
    if (added == null || !mounted) return;
    setState(() {
      _linkedProducts = [
        ..._linkedProducts,
        ...added.map(
          (p) {
            final img = p.images.isNotEmpty ? p.images.first.url : '';
            return BannerProductLink(
              productId: p.id,
              name: p.name,
              sku: p.sku,
              mrp: p.mrp,
              sellingPrice: p.sellingPrice,
              imageUrl: img,
              discountPct: 0,
              position: _linkedProducts.length,
            );
          },
        ),
      ];
    });
  }

  void _updateDiscount(int index, int newPct) {
    final clamped = newPct.clamp(0, 90);
    setState(() {
      final out = [..._linkedProducts];
      out[index] = out[index].copyWith(discountPct: clamped);
      _linkedProducts = out;
    });
  }

  void _removeLink(int index) {
    setState(() {
      _linkedProducts = [..._linkedProducts]..removeAt(index);
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final out = [..._linkedProducts];
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = out.removeAt(oldIndex);
      out.insert(newIndex, moved);
      _linkedProducts = out;
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title + image are required')),
      );
      return;
    }
    setState(() => _busy = true);
    final provider = context.read<MerchantCarouselProvider>();
    final body = <String, dynamic>{
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
      if (_startAt != null) 'startAt': _startAt!.toUtc().toIso8601String(),
      if (_endAt != null) 'endAt': _endAt!.toUtc().toIso8601String(),
      'isActive': _isActive,
    };

    final result = _isEdit
        ? await provider.update(widget.existing!.id, body)
        : await provider.create(body);
    if (!mounted) return;
    if (result == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_formatError(provider.error ?? 'Save failed'))),
      );
      return;
    }

    // Persist the linked-product list against the (possibly newly-created)
    // banner id. Done as a second request because the editor stays open
    // and lets the merchant tweak picks before saving.
    try {
      await provider.replaceLinkedProducts(result.id, _linkedProducts);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Slide saved, but linked products failed: ${_formatError(e.toString())}',
          ),
        ),
      );
      // Slide itself saved; close so the manager refreshes and the
      // merchant can retry the link step from the edit sheet.
      Navigator.of(context).pop(true);
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                _isEdit ? 'Edit slide' : 'New slide',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.huge,
            ),
            children: [
              _PreviewCard(
                title: _title.text.isEmpty ? 'Your slide title' : _title.text,
                subtitle: _subtitle.text.isEmpty ? null : _subtitle.text,
                eyebrow: _eyebrow.text.isEmpty ? null : _eyebrow.text,
                ctaText: _ctaText.text.isEmpty ? null : _ctaText.text,
                brandLabel: _brandLabel.text.isEmpty ? null : _brandLabel.text,
                imageUrl: _imageUrl,
                bgColor: _parseColor(_bgColor.text),
                accentColor: _parseColor(
                  _accentColor.text,
                  fallback: AppColors.black,
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              _imageRow(),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: 'Subtitle'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _eyebrow,
                      decoration: const InputDecoration(
                        labelText: 'Eyebrow',
                        helperText: 'Tiny copy above title',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextField(
                      controller: _brandLabel,
                      decoration:
                          const InputDecoration(labelText: 'Brand label'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _ctaText,
                decoration: const InputDecoration(
                  labelText: 'Button label',
                  hintText: 'e.g. Shop the deal',
                  helperText:
                      'Shown on the slide. Tapping it opens the product list below.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSizes.md),
              _linkedProductsSection(),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bgColor,
                      decoration: const InputDecoration(
                        labelText: 'BG color (#hex)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextField(
                      controller: _accentColor,
                      decoration: const InputDecoration(
                        labelText: 'Accent (#hex)',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _sortOrder,
                      decoration: const InputDecoration(labelText: 'Sort'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              _scheduleRow(),
              const SizedBox(height: AppSizes.lg),
              SwitchListTile.adaptive(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text('When off, hidden regardless of schedule'),
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? 'Saving…'
                      : (_isEdit ? 'Save changes' : 'Create slide'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Curated product list with per-row discount input. Empty state
  /// nudges the merchant to pick products; loaded state renders a
  /// reorderable list with thumbnail + discount stepper + remove.
  Widget _linkedProductsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surfaceTint,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined, size: 18),
              const SizedBox(width: AppSizes.sm),
              const Text(
                'Linked products',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _busy ? null : _openProductPicker,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const Text(
            'Customers who tap the slide will see these products with the discount applied. Cart still uses your regular selling price.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: AppSizes.sm),
          if (_loadingLinks)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_linkedProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
              child: Text(
                'No products linked yet. The slide will still publish, but tapping it will just open the home screen.',
                style: TextStyle(color: AppColors.muted.withValues(alpha: 0.9), fontSize: 12),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: _reorder,
              itemCount: _linkedProducts.length,
              itemBuilder: (_, i) {
                final link = _linkedProducts[i];
                return _LinkRow(
                  key: ValueKey('link-${link.productId}'),
                  index: i,
                  link: link,
                  onDelete: () => _removeLink(i),
                  onDiscountChanged: (v) => _updateDiscount(i, v),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _imageRow() {
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
          child: _imageUrl == null
              ? const Icon(Icons.image_outlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(_imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.upload_outlined),
            label: Text(_imageUrl == null ? 'Upload image *' : 'Replace image'),
            onPressed: _busy ? null : _pickImage,
          ),
        ),
      ],
    );
  }

  Widget _scheduleRow() {
    final df = DateFormat.yMMMd().add_jm();
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: 'Starts',
            value: _startAt,
            formatter: df,
            onTap: () => _pickDate(isStart: true),
            onClear: _startAt == null
                ? null
                : () => setState(() => _startAt = null),
          ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: _DateField(
            label: 'Ends',
            value: _endAt,
            formatter: df,
            onTap: () => _pickDate(isStart: false),
            onClear:
                _endAt == null ? null : () => setState(() => _endAt = null),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    super.key,
    required this.index,
    required this.link,
    required this.onDelete,
    required this.onDiscountChanged,
  });
  final int index;
  final BannerProductLink link;
  final VoidCallback onDelete;
  final ValueChanged<int> onDiscountChanged;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = link.discountPct > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusSm,
          side: const BorderSide(color: AppColors.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.sm),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_indicator, color: AppColors.subtle),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                child: link.imageUrl.isEmpty
                    ? const Icon(Icons.image_outlined, color: AppColors.muted)
                    : Image.network(
                        resolveImageUrl(link.imageUrl),
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
                    Text(
                      link.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    DefaultTextStyle.merge(
                      style: const TextStyle(fontSize: 11),
                      child: Row(
                        children: [
                          if (hasDiscount) ...[
                            Text(
                              '₹${link.sellingPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '₹${link.salePrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ] else
                            Text(
                              '₹${link.sellingPrice.toStringAsFixed(0)}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _DiscountStepper(
                value: link.discountPct,
                onChanged: onDiscountChanged,
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountStepper extends StatelessWidget {
  const _DiscountStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        children: [
          _StepBtn(
            icon: Icons.remove,
            onTap: value <= 0 ? null : () => onChanged(value - 5),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          _StepBtn(
            icon: Icons.add,
            onTap: value >= 90 ? null : () => onChanged(value + 5),
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(
          icon,
          size: 16,
          color: onTap == null ? AppColors.disabled : AppColors.black,
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.disabled,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null ? 'Not set' : formatter.format(value!),
          style: TextStyle(
            color: value == null ? AppColors.muted : AppColors.black,
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.ctaText,
    this.brandLabel,
    this.imageUrl,
    required this.bgColor,
    required this.accentColor,
  });
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final String? ctaText;
  final String? brandLabel;
  final String? imageUrl;
  final Color bgColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: ShapeDecoration(
        color: bgColor,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (imageUrl != null)
            Positioned.fill(
              left: null,
              right: 0,
              child: SizedBox(
                width: 180,
                child: Image.network(
                  resolveImageUrl(imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [bgColor, bgColor.withValues(alpha: 0)],
                  stops: const [0.5, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (brandLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      brandLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                if (eyebrow != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    eyebrow!,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.sm),
                SizedBox(
                  width: 200,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      height: 1.1,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (ctaText != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: 6,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.black,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                    ),
                    child: Text(
                      ctaText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
