import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_banners_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Modal sheet for creating or editing a banner. The slim banner is just
/// an image + placement + optional link + optional schedule, so the editor
/// is correspondingly lean: upload the artwork, pick where it shows, and
/// (optionally) when and where it links.
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
  late final TextEditingController _linkUrl;
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
    _linkUrl = TextEditingController(text: e?.linkUrl ?? '');
    _sortOrder = TextEditingController(text: '${e?.sortOrder ?? 0}');
    _imageUrl = e?.imageUrl;
    _startAt = e?.startAt;
    _endAt = e?.endAt;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _linkUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
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
        SnackBar(
          content: Text(
            shop.error ?? AppLocalizations.of(context).adminImageUploadFailed,
          ),
        ),
      );
      return;
    }
    setState(() => _imageUrl = url);
  }

  /// Hard 5 MB ceiling — anything bigger usually means the admin
  /// uploaded a raw camera capture, which both blows past the backend
  /// limit and stalls on slow connections.
  bool _validateImageSize(File file) {
    const maxBytes = 5 * 1024 * 1024;
    if (file.lengthSync() > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminImageTooLarge),
        ),
      );
      return false;
    }
    return true;
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
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      t.hour,
      t.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = combined;
      } else {
        _endAt = combined;
      }
    });
  }

  Future<void> _save() async {
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).adminBannerImageRequired),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final provider = context.read<AdminBannersProvider>();
    final body = <String, dynamic>{
      'placement': _placement.wire,
      'imageUrl': _imageUrl,
      if (_linkUrl.text.trim().isNotEmpty) 'linkUrl': _linkUrl.text.trim(),
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
        SnackBar(
          content: Text(
            provider.error ?? AppLocalizations.of(context).adminSaveFailed,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                _isEdit ? l10n.adminBannerEditTitle : l10n.adminBannerNewTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              IconButton(
                icon: const AppIcon(AppIcons.close),
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
              _imageRow(),
              const SizedBox(height: AppSizes.md),
              DropdownButtonFormField<BannerPlacement>(
                initialValue: _placement,
                decoration: InputDecoration(
                  labelText: l10n.adminBannerPlacementLabel,
                ),
                items: BannerPlacement.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _placement = v ?? _placement),
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _linkUrl,
                      decoration: InputDecoration(
                        labelText: l10n.adminBannerLinkLabel,
                        helperText: l10n.adminLinkTargetHelper,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _sortOrder,
                      decoration: InputDecoration(
                        labelText: l10n.adminSortLabel,
                      ),
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
                title: Text(l10n.adminActive),
                subtitle: Text(l10n.adminBannerActiveSubtitle),
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(
                  _busy
                      ? l10n.adminSaving
                      : (_isEdit
                            ? l10n.adminSaveChanges
                            : l10n.adminBannerCreate),
                ),
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
              ? AppIcon(AppIcons.imageOutlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(_imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const AppIcon(AppIcons.brokenImageOutlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: OutlinedButton.icon(
            icon: const AppIcon(AppIcons.uploadOutlined),
            label: Text(
              _imageUrl == null
                  ? AppLocalizations.of(context).adminBannerUploadImage
                  : AppLocalizations.of(context).adminReplaceImage,
            ),
            onPressed: _busy ? null : _pickImage,
          ),
        ),
      ],
    );
  }

  Widget _scheduleRow() {
    final l10n = AppLocalizations.of(context);
    final df = DateFormat.yMMMd().add_jm();
    return Row(
      children: [
        Expanded(
          child: _DateField(
            label: l10n.adminBannerStarts,
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
            label: l10n.adminBannerEnds,
            value: _endAt,
            formatter: df,
            onTap: () => _pickDate(isStart: false),
            onClear: _endAt == null
                ? null
                : () => setState(() => _endAt = null),
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
        width: AppSizes.handleWidth,
        height: AppSizes.handleHeight,
        decoration: BoxDecoration(
          color: AppColors.disabled,
          borderRadius: BorderRadius.circular(AppSizes.radiusXs),
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
                  icon: const AppIcon(AppIcons.close, size: AppSizes.iconMd),
                  onPressed: onClear,
                )
              : const AppIcon(
                  AppIcons.calendarTodayOutlined,
                  size: AppSizes.iconMd,
                ),
        ),
        child: Text(
          value == null
              ? AppLocalizations.of(context).adminNotSet
              : formatter.format(value!),
          style: TextStyle(
            color: value == null ? AppColors.muted : AppColors.black,
          ),
        ),
      ),
    );
  }
}
