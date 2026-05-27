import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';
import 'package:shopxy/features/carousel/presentation/pages/carousel_editor_page.dart';
import 'package:shopxy/features/carousel/presentation/providers/carousels_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Top-level merchant page: lists every carousel the shop owns,
/// grouped visually by placement. Tap a row to open the carousel
/// editor; the "+ New carousel" FAB creates a new one and pushes
/// straight into its editor.
///
/// Replaced the legacy `MyCarouselPage` + bottom-sheet editor in
/// Phase 7. The merchant has one canonical surface now; new shop
/// builds go straight here from the drawer shortcut.
class MyCarouselsPage extends StatefulWidget {
  const MyCarouselsPage({super.key});

  @override
  State<MyCarouselsPage> createState() => _MyCarouselsPageState();
}

class _MyCarouselsPageState extends State<MyCarouselsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CarouselsProvider>().load();
    });
  }

  Future<void> _createCarousel() async {
    final created = await _NewCarouselSheet.show(context);
    if (created == null || !mounted) return;
    await _openCarousel(created);
  }

  Future<void> _openCarousel(Carousel c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CarouselEditorPage(carouselId: c.id)),
    );
    if (!mounted) return;
    // The editor may have renamed / toggled / added slides — re-pull
    // the list so the count + active chips stay accurate.
    await context.read<CarouselsProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CarouselsProvider>();
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('My carousels'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: provider.isLoading ? null : () => provider.load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCarousel,
        icon: const Icon(Icons.add),
        label: const Text('New carousel'),
      ),
      body: _body(provider),
    );
  }

  Widget _body(CarouselsProvider p) {
    if (p.isLoading && p.carousels.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null && p.carousels.isEmpty) {
      return _ErrorView(message: p.error!, onRetry: () => p.load());
    }
    if (p.carousels.isEmpty) {
      return _EmptyView(onCreate: _createCarousel);
    }
    return RefreshIndicator(
      onRefresh: () => p.load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.huge,
        ),
        itemCount: p.carousels.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.md),
        itemBuilder: (_, i) {
          final c = p.carousels[i];
          return _CarouselCard(carousel: c, onTap: () => _openCarousel(c));
        },
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.carousel, required this.onTap});
  final Carousel carousel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final live = carousel.isActive;
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: const BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  color: live ? AppColors.brandSoft : AppColors.surfaceTint,
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.view_carousel_rounded,
                  color: live ? AppColors.brand : AppColors.muted,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carousel.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSizes.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MetaChip(
                          icon: Icons.place_outlined,
                          label: carousel.placement.label,
                        ),
                        _MetaChip(
                          icon: Icons.image_outlined,
                          label: '${carousel.slideCount} '
                              '${carousel.slideCount == 1 ? 'slide' : 'slides'}',
                        ),
                        if (live)
                          const _MetaChip(
                            icon: Icons.bolt_rounded,
                            label: 'Live',
                            tint: AppColors.brand,
                          )
                        else
                          const _MetaChip(
                            icon: Icons.pause_circle_outline,
                            label: 'Paused',
                            tint: AppColors.muted,
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.tint = AppColors.muted,
  });
  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 2,
      ),
      decoration: ShapeDecoration(
        color: AppColors.surfaceTint,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_carousel_outlined,
              size: 48,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            const Text(
              'No carousels yet',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 4),
            const Text(
              'Group your slides into named campaigns — "Spring sale", '
              '"New drops" — and toggle the whole campaign on or off in '
              'one tap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create a carousel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: AppSizes.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Minimal modal for "new carousel" — name + placement. Heavier
/// editing (schedule, on/off) lives inside `CarouselEditorPage`; this
/// sheet's only job is to get the merchant through to the editor with
/// a valid row created server-side.
class _NewCarouselSheet extends StatefulWidget {
  const _NewCarouselSheet();

  static Future<Carousel?> show(BuildContext context) {
    return showModalBottomSheet<Carousel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: ShapeDecoration(
            color: AppColors.canvas,
            shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
          ),
          padding: const EdgeInsets.all(AppSizes.lg),
          child: const _NewCarouselSheet(),
        ),
      ),
    );
  }

  @override
  State<_NewCarouselSheet> createState() => _NewCarouselSheetState();
}

class _NewCarouselSheetState extends State<_NewCarouselSheet> {
  final _name = TextEditingController();
  BannerPlacement _placement = BannerPlacement.hero;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your carousel a name')),
      );
      return;
    }
    setState(() => _busy = true);
    final created = await context.read<CarouselsProvider>().create({
      'name': name,
      'placement': _placement.wire,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (created == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<CarouselsProvider>().error ?? 'Create failed',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'New carousel',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Spring sale',
          ),
          maxLength: 80,
          autofocus: true,
        ),
        const SizedBox(height: AppSizes.md),
        DropdownButtonFormField<BannerPlacement>(
          initialValue: _placement,
          decoration: const InputDecoration(labelText: 'Placement'),
          items: BannerPlacement.values
              .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
              .toList(),
          onChanged: (v) => setState(() => _placement = v ?? _placement),
        ),
        const SizedBox(height: AppSizes.lg),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Creating…' : 'Create carousel'),
        ),
        const SizedBox(height: AppSizes.sm),
      ],
    );
  }
}
