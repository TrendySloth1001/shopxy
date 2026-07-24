import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_theme_spec.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// Theme studio — pick a curated **preset** (a full ready-made config) or go
/// **Custom** and compose each axis independently: Colour · Font · Corners ·
/// Density · Motion. Every change writes through [ThemePrefsProvider], which
/// recomposes the active [AppThemeSpec] and rebuilds the whole app live — so the
/// preview at the top (and the app behind it) reflects the choice instantly.
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
          const _PreviewCard(),
          _Eyebrow('Presets', trailing: preset == null ? 'Custom' : preset.label),
          _Wrap(
            children: [
              for (final p in kThemePresets)
                _Pill(
                  label: p.label,
                  selected: preset?.id == p.id,
                  onTap: () => prefs.applyPreset(p),
                ),
            ],
          ),
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
          const _Eyebrow('Corners'),
          _Wrap(
            children: [
              for (final s in AppShape.values)
                _Pill(
                  label: s.label,
                  selected: prefs.shape == s,
                  onTap: () => prefs.setShape(s),
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

/// Live preview of the current config — a headline, body copy, buttons, a chip
/// and an input, all rendered in the active theme.
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
              'A preview of your theme — colour, font, icons, corners, density '
              'and motion applied live across the app.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.md),
            // Sample icons — reflect the Icons axis live.
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.xs,
                  ),
                  decoration: ShapeDecoration(
                    color: AppColors.brandSoft,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(
                    'Chip',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.brandStrong,
                    ),
                  ),
                ),
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
  const _Eyebrow(this.label, {this.trailing});
  final String label;
  final String? trailing;

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
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.subtle,
              ),
            ),
        ],
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

/// A selectable text pill using the inverse-surface fill when selected (matches
/// the app's chip language).
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
