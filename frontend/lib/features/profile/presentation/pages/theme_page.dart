import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_theme_spec.dart';
import 'package:shopxy/shared/theme/app_typography.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// Theme picker — a gallery of ready-made **presets** shown as tappable previews
/// (no overwhelming rows of switches). A "Create custom" button opens the
/// [_CustomThemePage] for anyone who wants to compose their own. Every change
/// writes through [ThemePrefsProvider], which re-themes the whole app live.
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ThemePrefsProvider>();
    final preset = prefs.activePreset;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const FloatingAppBar(title: 'Theme'),
      body: ListView(
        padding: EdgeInsets.only(
          top: FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              0,
            ),
            child: Text(
              preset != null
                  ? 'Theme · ${preset.label}'
                  : 'Theme · Custom',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          // Preset gallery — tap a preview to apply it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppSizes.md,
              crossAxisSpacing: AppSizes.md,
              childAspectRatio: 0.82,
              children: [
                for (final p in kThemePresets)
                  _PresetCard(
                    preset: p,
                    selected: preset?.id == p.id,
                    onTap: () => prefs.applyPreset(p),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          // The escape hatch — full per-axis control lives behind this button.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const _CustomThemePage()),
              ),
              icon: AppIcon(AppIcons.tuneRounded, size: AppSizes.iconMd),
              label: const Text('Create custom'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A mini preview of one preset — canvas, a surface "window" with a title in the
/// preset's font, sample text bars, a brand button and an accent — plus the
/// name and a check when selected.
class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = ThemePrefsProvider.paletteFor(preset.palette);
    Widget bar(double widthFactor, Color color) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: ShapeDecoration(
          color: pal.canvas,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: BorderSide(
              color: selected ? pal.ink : pal.hairline,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        padding: const EdgeInsets.all(AppSizes.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mini window
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: ShapeDecoration(
                  color: pal.surface,
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: BorderSide(color: pal.hairline),
                  ),
                ),
                padding: const EdgeInsets.all(AppSizes.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aa',
                      style: AppTypography.sampleStyle(
                        preset.font,
                        color: pal.ink,
                        fontSize: 20,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    bar(1.0, pal.muted.withValues(alpha: 0.35)),
                    const SizedBox(height: AppSizes.xs),
                    bar(0.6, pal.muted.withValues(alpha: 0.25)),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 14,
                          decoration: BoxDecoration(
                            color: pal.brand,
                            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                          ),
                        ),
                        const SizedBox(width: AppSizes.xs),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: pal.brandSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  AppIcon(
                    AppIcons.checkCircleOutlineRounded,
                    size: AppSizes.iconSm,
                    color: AppColors.brand,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full per-axis composer — reached from the "Create custom" button. Colour ·
/// Font · Icons · Density · Motion. (Corners deliberately omitted.)
class _CustomThemePage extends StatelessWidget {
  const _CustomThemePage();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ThemePrefsProvider>();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const FloatingAppBar(title: 'Custom theme'),
      body: ListView(
        padding: EdgeInsets.only(
          top: FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge,
        ),
        children: [
          const _PreviewCard(),
          const _Eyebrow('Colour'),
          _Wrap(
            children: [
              for (final m in AppThemeMode.values)
                _SwatchPill(
                  label: paletteLabel(m),
                  color: ThemePrefsProvider.paletteFor(m).canvas,
                  ring: ThemePrefsProvider.paletteFor(m).hairline,
                  selected: prefs.mode == m,
                  onTap: () => prefs.setMode(m),
                ),
            ],
          ),
          const _Eyebrow('Font'),
          _Wrap(
            children: [
              for (final f in AppFont.values)
                _Pill(
                  label: f.label,
                  selected: prefs.font == f,
                  onTap: () => prefs.setFont(f),
                ),
            ],
          ),
          const _Eyebrow('Icons'),
          _Wrap(
            children: [
              for (final s in AppIconStyle.values)
                _Pill(
                  label: s.label,
                  selected: prefs.iconStyle == s,
                  onTap: () => prefs.setIconStyle(s),
                ),
            ],
          ),
          const _Eyebrow('Density'),
          _Wrap(
            children: [
              for (final d in AppDensityChoice.values)
                _Pill(
                  label: d.label,
                  selected: prefs.density == d,
                  onTap: () => prefs.setDensity(d),
                ),
            ],
          ),
          const _Eyebrow('Motion'),
          _Wrap(
            children: [
              for (final m in AppMotionChoice.values)
                _Pill(
                  label: m.label,
                  selected: prefs.motion == m,
                  onTap: () => prefs.setMotion(m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Live preview of the current config — used on the custom page.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: ShapeDecoration(
          color: AppColors.surface,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The quick brown fox', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSizes.xs),
            Text(
              'A preview of your theme — colour, font, icons, density and '
              'motion applied live across the app.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                for (final g in const [
                  AppIcons.homeOutlined,
                  AppIcons.receiptLongOutlined,
                  AppIcons.personOutline,
                  AppIcons.settingsOutlined,
                  AppIcons.searchRounded,
                  AppIcons.deleteOutline,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSizes.md),
                    child: AppIcon(g, size: AppSizes.iconLg, color: AppColors.black),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Primary')),
                OutlinedButton(onPressed: () {}, child: const Text('Secondary')),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              decoration: const InputDecoration(hintText: 'Sample input'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Wrap extends StatelessWidget {
  const _Wrap({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Wrap(spacing: AppSizes.sm, runSpacing: AppSizes.sm, children: children),
    );
  }
}

/// A selectable text pill (inverse-surface fill when selected).
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        decoration: ShapeDecoration(
          color: selected ? AppColors.inverseSurface : AppColors.surface,
          shape: AppShapes.squircle(
            AppSizes.radiusFull,
            side: BorderSide(
              color: selected ? AppColors.inverseSurface : AppColors.hairline,
            ),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: selected ? AppColors.onInverse : AppColors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A colour-swatch pill for the colour axis — a filled dot + label.
class _SwatchPill extends StatelessWidget {
  const _SwatchPill({
    required this.label,
    required this.color,
    required this.ring,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final Color ring;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.xs,
          AppSizes.xs,
          AppSizes.md,
          AppSizes.xs,
        ),
        decoration: ShapeDecoration(
          color: AppColors.surface,
          shape: AppShapes.squircle(
            AppSizes.radiusFull,
            side: BorderSide(
              color: selected ? AppColors.inverseSurface : AppColors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSizes.iconLg,
              height: AppSizes.iconLg,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: ring),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
