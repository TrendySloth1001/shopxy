import 'package:flutter/material.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// Sliders + toggles for a FREEFORM slide's `imageTransform`. The
/// canvas above re-renders live as the merchant drags any slider, so
/// every change is preview-immediate.
///
/// Server-side bounds (see freeform-payload.ts): focal [0,100], scale
/// [0.25,4], rotateDeg [-180,180], filter axes [0.5,1.5]. The sliders
/// match those ranges exactly so a server reject is impossible from
/// this surface (defensive zod still runs).
class ImageTransformPanel extends StatelessWidget {
  const ImageTransformPanel({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final CarouselSlideImageTransform value;
  final ValueChanged<CarouselSlideImageTransform> onChanged;

  void _patch({
    double? focalXPct,
    double? focalYPct,
    double? scale,
    double? rotateDeg,
    bool? flipH,
    bool? flipV,
    double? brightness,
    double? contrast,
    double? saturation,
  }) {
    onChanged(value.copyWith(
      focalXPct: focalXPct,
      focalYPct: focalYPct,
      scale: scale,
      rotateDeg: rotateDeg,
      flipH: flipH,
      flipV: flipV,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupLabel('Crop focal point'),
        _LabeledSlider(
          label: 'Horizontal',
          value: value.focalXPct,
          min: 0,
          max: 100,
          unit: '%',
          onChanged: (v) => _patch(focalXPct: v),
        ),
        _LabeledSlider(
          label: 'Vertical',
          value: value.focalYPct,
          min: 0,
          max: 100,
          unit: '%',
          onChanged: (v) => _patch(focalYPct: v),
        ),
        const SizedBox(height: AppSizes.md),
        const _GroupLabel('Transform'),
        _LabeledSlider(
          label: 'Zoom',
          value: value.scale,
          min: 0.25,
          max: 4,
          onChanged: (v) => _patch(scale: v),
          fractionDigits: 2,
        ),
        _LabeledSlider(
          label: 'Rotate',
          value: value.rotateDeg,
          min: -180,
          max: 180,
          unit: '°',
          onChanged: (v) => _patch(rotateDeg: v),
          fractionDigits: 0,
        ),
        Row(
          children: [
            Expanded(
              child: SwitchListTile.adaptive(
                value: value.flipH,
                onChanged: (v) => _patch(flipH: v),
                title: const Text('Flip horizontal'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: SwitchListTile.adaptive(
                value: value.flipV,
                onChanged: (v) => _patch(flipV: v),
                title: const Text('Flip vertical'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        const _GroupLabel('Colour filters'),
        _LabeledSlider(
          label: 'Brightness',
          value: value.brightness,
          min: 0.5,
          max: 1.5,
          onChanged: (v) => _patch(brightness: v),
          fractionDigits: 2,
        ),
        _LabeledSlider(
          label: 'Contrast',
          value: value.contrast,
          min: 0.5,
          max: 1.5,
          onChanged: (v) => _patch(contrast: v),
          fractionDigits: 2,
        ),
        _LabeledSlider(
          label: 'Saturation',
          value: value.saturation,
          min: 0.5,
          max: 1.5,
          onChanged: (v) => _patch(saturation: v),
          fractionDigits: 2,
        ),
        const SizedBox(height: AppSizes.sm),
        TextButton.icon(
          onPressed: () => onChanged(CarouselSlideImageTransform.identity),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reset all'),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sm, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
    this.fractionDigits = 0,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String unit;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(
            '${value.toStringAsFixed(fractionDigits)}$unit',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}
