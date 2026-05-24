import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_banners_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Modal sheet for creating or editing a banner. The "preview" panel at
/// the top is a deliberately faithful copy of how the customer hero
/// card renders so the admin doesn't have to context-switch to the
/// customer app to see their colour/copy choices.
class AdminBannerEditorSheet extends StatefulWidget {
  const AdminBannerEditorSheet({super.key, this.existing});
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
          child: AdminBannerEditorSheet(existing: existing),
        ),
      ),
    );
  }

  @override
  State<AdminBannerEditorSheet> createState() => _AdminBannerEditorSheetState();
}

class _AdminBannerEditorSheetState extends State<AdminBannerEditorSheet> {
  late BannerPlacement _placement;
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _eyebrow;
  late final TextEditingController _ctaText;
  late final TextEditingController _ctaTarget;
  late final TextEditingController _brandLabel;
  late final TextEditingController _bgColor;
  late final TextEditingController _accentColor;
  late final TextEditingController _sortOrder;
  String? _imageUrl;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _isActive = true;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _placement = e?.placement ?? BannerPlacement.hero;
    _title = TextEditingController(text: e?.title ?? '');
    _subtitle = TextEditingController(text: e?.subtitle ?? '');
    _eyebrow = TextEditingController(text: e?.eyebrow ?? '');
    _ctaText = TextEditingController(text: e?.ctaText ?? '');
    _ctaTarget = TextEditingController(text: e?.ctaTarget ?? '');
    _brandLabel = TextEditingController(text: e?.brandLabel ?? '');
    _bgColor = TextEditingController(text: e?.bgColor ?? '#EFE4D6');
    _accentColor = TextEditingController(text: e?.accentColor ?? '#B23A2E');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _imageUrl = e?.imageUrl;
    _startAt = e?.startAt;
    _endAt = e?.endAt;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _eyebrow.dispose();
    _ctaText.dispose();
    _ctaTarget.dispose();
    _brandLabel.dispose();
    _bgColor.dispose();
    _accentColor.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
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
    final combined = DateTime(date.year, date.month, date.day, t.hour, t.minute);
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

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title + image are required')),
      );
      return;
    }
    setState(() => _busy = true);
    final provider = context.read<AdminBannersProvider>();
    final body = <String, dynamic>{
      'placement': _placement.wire,
      'title': _title.text.trim(),
      if (_subtitle.text.trim().isNotEmpty) 'subtitle': _subtitle.text.trim(),
      if (_eyebrow.text.trim().isNotEmpty) 'eyebrow': _eyebrow.text.trim(),
      if (_ctaText.text.trim().isNotEmpty) 'ctaText': _ctaText.text.trim(),
      if (_ctaTarget.text.trim().isNotEmpty) 'ctaTarget': _ctaTarget.text.trim(),
      if (_brandLabel.text.trim().isNotEmpty) 'brandLabel': _brandLabel.text.trim(),
      'imageUrl': _imageUrl,
      'bgColor': _bgColor.text.trim(),
      if (_accentColor.text.trim().isNotEmpty) 'accentColor': _accentColor.text.trim(),
      'sortOrder': int.tryParse(_sortOrder.text) ?? 0,
      if (_startAt != null) 'startAt': _startAt!.toUtc().toIso8601String(),
      if (_endAt != null) 'endAt': _endAt!.toUtc().toIso8601String(),
      'isActive': _isActive,
    };
    final result = _isEdit
        ? await provider.update(widget.existing!.id, body)
        : await provider.create(body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Save failed')),
      );
    }
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
                _isEdit ? 'Edit banner' : 'New banner',
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
                title: _title.text.isEmpty ? 'Your banner title' : _title.text,
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
              DropdownButtonFormField<BannerPlacement>(
                initialValue: _placement,
                decoration: const InputDecoration(labelText: 'Placement'),
                items: BannerPlacement.values
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                    .toList(),
                onChanged: (v) => setState(() => _placement = v ?? _placement),
              ),
              const SizedBox(height: AppSizes.md),
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
                      decoration: const InputDecoration(labelText: 'Brand label'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctaText,
                      decoration: const InputDecoration(labelText: 'CTA text'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextField(
                      controller: _ctaTarget,
                      decoration: const InputDecoration(
                        labelText: 'CTA target',
                        helperText: 'category:slug | product:id | url:https://…',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
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
                child: Text(_busy ? 'Saving…' : (_isEdit ? 'Save changes' : 'Create banner')),
              ),
            ],
          ),
        ),
      ],
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
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
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
            onClear: _endAt == null ? null : () => setState(() => _endAt = null),
          ),
        ),
      ],
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

/// Visual approximation of the customer hero card — keeps admins from
/// publishing low-contrast text or accidentally invisible banners.
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
