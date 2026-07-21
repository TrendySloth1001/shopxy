import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/constants/app_curves.dart';

/// Skeleton-loader primitive. Rule from DESIGN.md #4: loading uses
/// skeletons (mirroring final layout) instead of spinners.
///
/// Use `AppShimmerBox` for arbitrary blocks (image placeholders,
/// rounded rectangles). Use `AppShimmerLine` for text lines —
/// pre-styled to 12dp tall with a sane radius.
///
/// All shimmer boxes pulse in sync (one shared `AnimationController`
/// would be ideal but a tiny per-widget ticker is cheap on a phone and
/// avoids leaking state across routes).
class AppShimmerBox extends StatefulWidget {
  const AppShimmerBox({
    super.key,
    this.width,
    this.height = AppSizes.lg,
    this.radius = AppSizes.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppShimmerBox> createState() => _AppShimmerBoxState();
}

class _AppShimmerBoxState extends State<AppShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: ShapeDecoration(
          color: AppColors.surfaceTint,
          shape: AppShapes.squircle(widget.radius),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            color: Color.lerp(AppColors.surfaceTint, AppColors.hairline, t),
            shape: AppShapes.squircle(widget.radius),
          ),
        );
      },
    );
  }
}

/// One line of skeleton text. `widthFactor` controls how wide the line
/// is relative to its parent (0.6 means 60% — useful for headings).
class AppShimmerLine extends StatelessWidget {
  const AppShimmerLine({
    super.key,
    this.widthFactor = 1.0,
    this.height = AppSizes.md,
  });
  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    // `FractionallySizedBox` can't take a fraction of an unbounded width —
    // dropping a shimmer line straight into a `Row` (a common skeleton shape:
    // Expanded text block + a short trailing bar) hands it infinite width and
    // throws. `LimitedBox` caps the width ONLY when the parent is unbounded, so
    // the bar still renders there; in a bounded parent it's a no-op and the
    // fraction-of-parent behaviour is pixel-identical.
    //
    // NB: do NOT use LayoutBuilder here — it can't answer intrinsic-dimension
    // queries, which breaks IntrinsicHeight (used by some skeletons) and leaves
    // slivers with null geometry that then crash during paint. LimitedBox
    // delegates intrinsics to its child, so IntrinsicHeight keeps working.
    return LimitedBox(
      maxWidth: 220,
      child: FractionallySizedBox(
        widthFactor: widthFactor.clamp(0.1, 1.0),
        alignment: Alignment.centerLeft,
        child: AppShimmerBox(height: height, radius: height / 2),
      ),
    );
  }
}

/// Convenience: animate any child in once it's ready, after a brief
/// fade from the shimmer. Use sparingly — for hero list reveals only.
class AppFadeIn extends StatelessWidget {
  const AppFadeIn({
    super.key,
    required this.child,
    this.duration = AppDurations.medium,
  });
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: 1,
      duration: reduceMotion ? Duration.zero : duration,
      curve: AppCurves.decelerate,
      child: child,
    );
  }
}
