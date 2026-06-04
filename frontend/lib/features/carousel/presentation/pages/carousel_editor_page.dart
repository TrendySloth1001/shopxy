import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';
import 'package:shopxy/features/carousel/presentation/pages/slide_editor_page.dart';
import 'package:shopxy/features/carousel/presentation/providers/carousels_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Full-page carousel editor. Shows:
///   1. Carousel-level meta — name, placement, schedule, on/off.
///      Edits save inline on blur / toggle change with optimistic UI.
///   2. Slides list — every slide in the carousel, ordered, with
///      thumbnail + title + mode chip + per-slide on/off.
///
/// The "+ Add slide" CTA pushes `SlideEditorPage` in create mode; tap
/// an existing slide row to push the same page in edit mode.
class CarouselEditorPage extends StatefulWidget {
  const CarouselEditorPage({super.key, required this.carouselId});
  final int carouselId;

  @override
  State<CarouselEditorPage> createState() => _CarouselEditorPageState();
}

class _CarouselEditorPageState extends State<CarouselEditorPage> {
  bool _initialLoad = true;
  bool _savingMeta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // The carousels list endpoint returns _count.slides but doesn't
      // hydrate the slides themselves; pull them now so the page can
      // render rows on first paint.
      await context.read<CarouselsProvider>().loadSlides(widget.carouselId);
      if (!mounted) return;
      setState(() => _initialLoad = false);
    });
  }

  Carousel? _carousel(CarouselsProvider p) {
    for (final c in p.carousels) {
      if (c.id == widget.carouselId) return c;
    }
    return null;
  }

  Future<void> _openSlide({CarouselSlide? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SlideEditorPage(
          carouselId: widget.carouselId,
          existing: existing,
        ),
      ),
    );
    if (changed == true && mounted) {
      await context.read<CarouselsProvider>().loadSlides(widget.carouselId);
    }
  }

  Future<void> _updateMeta(Map<String, dynamic> patch) async {
    if (_savingMeta) return;
    setState(() => _savingMeta = true);
    final ok = await context.read<CarouselsProvider>().update(
          widget.carouselId,
          patch,
        );
    if (!mounted) return;
    setState(() => _savingMeta = false);
    if (ok == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<CarouselsProvider>().error ?? 'Save failed',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete carousel?'),
        content: const Text(
          'Every slide inside it will be removed too. This cannot be '
          'undone.',
        ),
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
    final success =
        await context.read<CarouselsProvider>().delete(widget.carouselId);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CarouselsProvider>();
    final c = _carousel(provider);
    final slides = provider.slidesFor(widget.carouselId);
    final loadingSlides = provider.isLoadingSlides(widget.carouselId);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(c?.name ?? 'Carousel'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: c == null ? null : _confirmDelete,
          ),
        ],
      ),
      floatingActionButton: c == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openSlide(),
              icon: const Icon(Icons.add),
              label: const Text('Add slide'),
            ),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context
                  .read<CarouselsProvider>()
                  .loadSlides(widget.carouselId),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.md,
                  AppSizes.lg,
                  AppSizes.huge,
                ),
                children: [
                  _MetaCard(
                    carousel: c,
                    busy: _savingMeta,
                    onSubmit: _updateMeta,
                  ),
                  const SizedBox(height: AppSizes.lg),
                  Row(
                    children: [
                      Text(
                        'Slides',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      if (loadingSlides)
                        const SizedBox(
                          width: AppSizes.lg,
                          height: AppSizes.lg,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          '· ${slides.length}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  if (!loadingSlides && !_initialLoad && slides.isEmpty)
                    const _EmptySlides()
                  else
                    ...slides.map(
                      (s) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSizes.sm),
                        child: _SlideRow(
                          slide: s,
                          onTap: () => _openSlide(existing: s),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MetaCard extends StatefulWidget {
  const _MetaCard({
    required this.carousel,
    required this.busy,
    required this.onSubmit,
  });
  final Carousel carousel;
  final bool busy;
  final Future<void> Function(Map<String, dynamic>) onSubmit;

  @override
  State<_MetaCard> createState() => _MetaCardState();
}

class _MetaCardState extends State<_MetaCard> {
  late TextEditingController _name;
  late BannerPlacement _placement;
  late bool _isActive;
  DateTime? _startAt;
  DateTime? _endAt;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.carousel.name);
    _placement = widget.carousel.placement;
    _isActive = widget.carousel.isActive;
    _startAt = widget.carousel.startAt;
    _endAt = widget.carousel.endAt;
  }

  // No didUpdateWidget: the State is rebuilt fresh whenever the
  // merchant navigates back into the editor, and CarouselsProvider
  // updates fire here as Provider rebuilds — but we *don't* want to
  // re-sync controllers mid-edit. Resyncing on every save round-trip
  // races with in-flight keystrokes ("Spring" typed → save fires →
  // user types " sale" → save response stomps it back to "Spring").
  // The fields are merchant-authoritative until they leave the page.

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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
    await widget.onSubmit({
      if (isStart) 'startAt': combined.toUtc().toIso8601String(),
      if (!isStart) 'endAt': combined.toUtc().toIso8601String(),
    });
  }

  Future<void> _clearDate({required bool isStart}) async {
    setState(() {
      if (isStart) {
        _startAt = null;
      } else {
        _endAt = null;
      }
    });
    await widget.onSubmit({if (isStart) 'startAt': null, if (!isStart) 'endAt': null});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Name'),
            onSubmitted: (v) {
              if (v.trim().isEmpty) return;
              widget.onSubmit({'name': v.trim()});
            },
            onEditingComplete: () {
              final v = _name.text.trim();
              if (v.isEmpty || v == widget.carousel.name) return;
              widget.onSubmit({'name': v});
            },
          ),
          const SizedBox(height: AppSizes.sm),
          DropdownButtonFormField<BannerPlacement>(
            initialValue: _placement,
            decoration: const InputDecoration(labelText: 'Placement'),
            items: BannerPlacement.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: widget.busy
                ? null
                : (v) {
                    if (v == null || v == _placement) return;
                    setState(() => _placement = v);
                    widget.onSubmit({'placement': v.wire});
                  },
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Starts at',
                  value: _startAt,
                  onTap: () => _pickDate(isStart: true),
                  onClear:
                      _startAt == null ? null : () => _clearDate(isStart: true),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _DateField(
                  label: 'Ends at',
                  value: _endAt,
                  onTap: () => _pickDate(isStart: false),
                  onClear:
                      _endAt == null ? null : () => _clearDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          SwitchListTile.adaptive(
            value: _isActive,
            onChanged: widget.busy
                ? null
                : (v) {
                    setState(() => _isActive = v);
                    widget.onSubmit({'isActive': v});
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text(
              'When off, every slide in this carousel is hidden regardless '
              'of its own settings.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideRow extends StatelessWidget {
  const _SlideRow({required this.slide, required this.onTap});
  final CarouselSlide slide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                child: SizedBox(
                  width: AppSizes.huge,
                  height: AppSizes.huge,
                  child: Image.network(
                    resolveImageUrl(slide.imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.surfaceTint,
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppColors.muted,
                      ),
                    ),
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
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      children: [
                        Text(
                          slide.template.label,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        if (!slide.isActive)
                          Text(
                            'Off',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySlides extends StatelessWidget {
  const _EmptySlides();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.surfaceTint,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Text(
        "No slides yet — tap \"Add slide\" to design your first one.",
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.muted),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  static final _fmt = DateFormat('d MMM yyyy · HH:mm');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: AppSizes.iconMd),
                  onPressed: onClear,
                )
              : const Icon(
                  Icons.calendar_today_outlined,
                  size: AppSizes.iconMd,
                ),
        ),
        child: Text(
          value == null ? 'Not set' : _fmt.format(value!),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: value == null ? AppColors.muted : AppColors.black,
              ),
        ),
      ),
    );
  }
}
