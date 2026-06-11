import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/features/spotlight/data/models/spotlight.dart';
import 'package:shopxy/features/spotlight/presentation/providers/spotlight_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';

/// Lets a merchant request a "brand of the day" placement. The request
/// lands as PENDING — a platform admin must approve before it appears
/// on the customer home strip. The existing requests list at the top
/// shows where each submission stands (pending / approved / rejected).
class SpotlightRequestPage extends StatefulWidget {
  const SpotlightRequestPage({super.key});

  @override
  State<SpotlightRequestPage> createState() => _SpotlightRequestPageState();
}

class _SpotlightRequestPageState extends State<SpotlightRequestPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SpotlightProvider>().load();
    });
  }

  Future<void> _openSubmitSheet() async {
    final ok = await _SpotlightSubmitSheet.show(context);
    if (ok == true && mounted) {
      await context.read<SpotlightProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpotlightProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Brand spotlight')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubmitSheet,
        icon: const Icon(Icons.add),
        label: const Text('Request slot'),
      ),
      body: provider.isLoading && provider.items.isEmpty
          ? const _SpotlightPageSkeleton()
          : RefreshIndicator(
              onRefresh: provider.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.lg,
                  AppSizes.fabClearance,
                ),
                children: [
                  const _ExplainerCard(),
                  const SizedBox(height: AppSizes.lg),
                  if (provider.items.isEmpty)
                    const _EmptyState()
                  else
                    for (final s in provider.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.md),
                        child: _SpotlightCard(
                          spotlight: s,
                          onCancel: s.status == SpotlightStatus.pending
                              ? () => provider.cancel(s.id)
                              : null,
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton (shimmer loading state)
// ---------------------------------------------------------------------------

class _SpotlightPageSkeleton extends StatelessWidget {
  const _SpotlightPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.fabClearance,
      ),
      children: const [
        _ExplainerCardSkeleton(),
        SizedBox(height: AppSizes.lg),
        _SpotlightCardSkeleton(),
        SizedBox(height: AppSizes.md),
        _SpotlightCardSkeleton(),
        SizedBox(height: AppSizes.md),
        _SpotlightCardSkeleton(),
      ],
    );
  }
}

/// Mirrors the _ExplainerCard: a rounded panel with a small icon placeholder
/// on the left and two lines of shimmer text on the right.
class _ExplainerCardSkeleton extends StatelessWidget {
  const _ExplainerCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.95, height: 12),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.75, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors _SpotlightCard: colored header with image + title/subtitle shimmer,
/// then a footer with a schedule line and a button-area placeholder.
class _SpotlightCardSkeleton extends StatelessWidget {
  const _SpotlightCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — mirrors the colored ClipPath section
          ClipPath(
            clipper: ShapeBorderClipper(
              shape: AppShapes.squircleTop(AppSizes.radiusLg),
            ),
            child: Container(
              color: AppColors.heroPanel,
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  AppShimmerBox(
                    width: AppSizes.massive,
                    height: AppSizes.massive,
                    radius: AppSizes.radiusMd,
                  ),
                  const SizedBox(width: AppSizes.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerLine(widthFactor: 0.7, height: 14),
                        SizedBox(height: AppSizes.xs),
                        AppShimmerLine(widthFactor: 0.5, height: 11),
                      ],
                    ),
                  ),
                  // Status chip placeholder
                  AppShimmerBox(width: 64, height: 24, radius: AppSizes.radiusSm),
                ],
              ),
            ),
          ),
          // Footer — schedule row + cancel button area
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppShimmerBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      radius: AppSizes.radiusSm,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    const Expanded(
                      child: AppShimmerLine(widthFactor: 0.65, height: 11),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppShimmerBox(
                    width: 120,
                    height: 32,
                    radius: AppSizes.radiusMd,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Real content widgets
// ---------------------------------------------------------------------------

class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.black),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Text(
              'Pitch your shop for a featured "brand of the day" slot. '
              'A platform admin reviews each request — typically same-day.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.huge),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, size: AppSizes.iconHuge, color: AppColors.muted),
          const SizedBox(height: AppSizes.md),
          Text(
            'No spotlight requests yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Tap "Request slot" to submit your first one.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightCard extends StatelessWidget {
  const _SpotlightCard({required this.spotlight, this.onCancel});
  final Spotlight spotlight;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.MMMd().add_jm();
    final bg = _parseColor(spotlight.bgColor);
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipPath(
            clipper: ShapeBorderClipper(
              shape: AppShapes.squircleTop(AppSizes.radiusLg),
            ),
            child: Container(
              color: bg,
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.massive,
                    height: AppSizes.massive,
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: AppColors.heroPanel,
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: Image.network(
                      resolveImageUrl(spotlight.heroImageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spotlight.dealLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (spotlight.subtitle != null) ...[
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            spotlight.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _StatusChip(status: spotlight.status),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: AppSizes.iconSm, color: AppColors.muted),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        '${df.format(spotlight.startAt.toLocal())}  →  ${df.format(spotlight.endAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (spotlight.status == SpotlightStatus.rejected &&
                    spotlight.rejectionReason != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: ShapeDecoration(
                      color: AppColors.errorSoft,
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: Text(
                      'Reason: ${spotlight.rejectionReason!}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                          ),
                    ),
                  ),
                ],
                if (onCancel != null) ...[
                  const SizedBox(height: AppSizes.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, size: AppSizes.iconSm),
                      label: const Text('Cancel request'),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SpotlightStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    switch (status) {
      case SpotlightStatus.pending:
        bg = AppColors.heroPanel;
        fg = AppColors.black;
        break;
      case SpotlightStatus.approved:
        bg = AppColors.successSoft;
        fg = AppColors.success;
        break;
      case SpotlightStatus.rejected:
        bg = AppColors.errorSoft;
        fg = AppColors.error;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

Color _parseColor(String hex, {Color fallback = AppColors.heroPanel}) {
  final m = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
  if (m == null) return fallback;
  var raw = m.group(1)!;
  if (raw.length == 6) raw = 'FF$raw';
  return Color(int.parse(raw, radix: 16));
}

class _SpotlightSubmitSheet extends StatefulWidget {
  const _SpotlightSubmitSheet();

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, _) => Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          child: const _SpotlightSubmitSheet(),
        ),
      ),
    );
  }

  @override
  State<_SpotlightSubmitSheet> createState() => _SpotlightSubmitSheetState();
}

enum _CtaKind { none, category, product, collection, url }

class _SpotlightSubmitSheetState extends State<_SpotlightSubmitSheet> {
  final _dealLabel = TextEditingController();
  final _subtitle = TextEditingController();
  final _bgColor = TextEditingController(text: '#EFE4D6');
  final _accentColor = TextEditingController(text: '#B23A2E');
  final _ctaValue = TextEditingController();
  _CtaKind _ctaKind = _CtaKind.none;
  String? _ctaError;
  String? _imageUrl;
  DateTime? _startAt;
  DateTime? _endAt;
  bool _busy = false;

  @override
  void dispose() {
    _dealLabel.dispose();
    _subtitle.dispose();
    _bgColor.dispose();
    _accentColor.dispose();
    _ctaValue.dispose();
    super.dispose();
  }

  /// Build (and validate) the DSL string the backend's cta-target parser
  /// expects. Returns null if the user picked "no CTA"; throws via the
  /// _ctaError state when the value doesn't match the chosen kind so the
  /// merchant doesn't have to round-trip to the server to learn that.
  String? _buildCtaTarget() {
    final value = _ctaValue.text.trim();
    switch (_ctaKind) {
      case _CtaKind.none:
        return null;
      case _CtaKind.category:
      case _CtaKind.collection:
        if (!RegExp(r'^[a-z0-9-]{1,80}$').hasMatch(value)) {
          setState(() => _ctaError = 'Lowercase letters, digits, hyphens only');
          return null;
        }
        return '${_ctaKind == _CtaKind.category ? 'category' : 'collection'}:$value';
      case _CtaKind.product:
        if (!RegExp(r'^\d+$').hasMatch(value)) {
          setState(() => _ctaError = 'Numeric product id required');
          return null;
        }
        return 'product:$value';
      case _CtaKind.url:
        final uri = Uri.tryParse(value);
        if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
          setState(() => _ctaError = 'Must be a full http(s):// URL');
          return null;
        }
        return 'url:$value';
    }
  }

  Future<void> _pickImage() async {
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
        const SnackBar(
          content: Text(
            'Image is larger than 5 MB. Pick a smaller image or crop tighter.',
          ),
        ),
      );
      return;
    }
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

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startAt : _endAt) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Future<void> _submit() async {
    if (_dealLabel.text.trim().isEmpty || _imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deal label + image are required')),
      );
      return;
    }
    if (_startAt == null || _endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick start and end times')),
      );
      return;
    }
    if (!_endAt!.isAfter(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End must be after start')),
      );
      return;
    }
    setState(() => _ctaError = null);
    String? ctaTarget;
    if (_ctaKind != _CtaKind.none) {
      if (_ctaValue.text.trim().isEmpty) {
        setState(() => _ctaError = 'Enter the CTA target value');
        return;
      }
      ctaTarget = _buildCtaTarget();
      if (ctaTarget == null) return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'dealLabel': _dealLabel.text.trim(),
      if (_subtitle.text.trim().isNotEmpty) 'subtitle': _subtitle.text.trim(),
      'heroImageUrl': _imageUrl,
      'bgColor': _bgColor.text.trim(),
      if (_accentColor.text.trim().isNotEmpty)
        'accentColor': _accentColor.text.trim(),
      'ctaTarget': ?ctaTarget,
      'startAt': _startAt!.toUtc().toIso8601String(),
      'endAt': _endAt!.toUtc().toIso8601String(),
    };
    final result = await context.read<SpotlightProvider>().submit(body);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result != null) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<SpotlightProvider>().error ?? 'Submit failed',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _DragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                'Request brand spotlight',
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
              _ImageRow(
                imageUrl: _imageUrl,
                onPick: _busy ? null : _pickImage,
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _dealLabel,
                decoration: const InputDecoration(
                  labelText: 'Deal label *',
                  helperText: 'e.g. "Festive Kurta Sets — Up to 40% off"',
                ),
              ),
              const SizedBox(height: AppSizes.md),
              TextField(
                controller: _subtitle,
                decoration: const InputDecoration(labelText: 'Subtitle'),
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
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: TextField(
                      controller: _accentColor,
                      decoration: const InputDecoration(
                        labelText: 'Accent (#hex)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.md),
              _CtaTargetField(
                kind: _ctaKind,
                value: _ctaValue,
                errorText: _ctaError,
                onKindChanged: (k) => setState(() {
                  _ctaKind = k;
                  _ctaError = null;
                }),
              ),
              const SizedBox(height: AppSizes.lg),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Starts',
                      value: _startAt,
                      formatter: df,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _DateField(
                      label: 'Ends',
                      value: _endAt,
                      formatter: df,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Submitting…' : 'Submit for review'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.imageUrl, required this.onPick});
  final String? imageUrl;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              ? const Icon(Icons.image_outlined, color: AppColors.muted)
              : Image.network(
                  resolveImageUrl(imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.upload_outlined),
            label: Text(imageUrl == null ? 'Upload image *' : 'Replace image'),
            onPressed: onPick,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onTap,
  });
  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? 'Pick…' : formatter.format(value!)),
      ),
    );
  }
}

class _CtaTargetField extends StatelessWidget {
  const _CtaTargetField({
    required this.kind,
    required this.value,
    required this.errorText,
    required this.onKindChanged,
  });
  final _CtaKind kind;
  final TextEditingController value;
  final String? errorText;
  final ValueChanged<_CtaKind> onKindChanged;

  String get _hint {
    switch (kind) {
      case _CtaKind.none:
        return 'No CTA — tapping the spotlight does nothing';
      case _CtaKind.category:
        return 'slug e.g. "kurta-sets"';
      case _CtaKind.product:
        return 'numeric product id';
      case _CtaKind.collection:
        return 'slug e.g. "festive-edit"';
      case _CtaKind.url:
        return 'https://…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<_CtaKind>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'CTA action'),
                items: const [
                  DropdownMenuItem(value: _CtaKind.none, child: Text('None')),
                  DropdownMenuItem(
                    value: _CtaKind.category,
                    child: Text('Open category'),
                  ),
                  DropdownMenuItem(
                    value: _CtaKind.product,
                    child: Text('Open product'),
                  ),
                  DropdownMenuItem(
                    value: _CtaKind.collection,
                    child: Text('Open collection'),
                  ),
                  DropdownMenuItem(
                    value: _CtaKind.url,
                    child: Text('External URL'),
                  ),
                ],
                onChanged: (k) => k == null ? null : onKindChanged(k),
              ),
            ),
            if (kind != _CtaKind.none) ...[
              const SizedBox(width: AppSizes.md),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: value,
                  decoration: InputDecoration(
                    labelText: 'Target',
                    helperText: _hint,
                    errorText: errorText,
                  ),
                  keyboardType: kind == _CtaKind.product
                      ? TextInputType.number
                      : TextInputType.text,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.xxxl,
      height: AppSizes.xs,
      margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.hairline,
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
      ),
    );
  }
}
