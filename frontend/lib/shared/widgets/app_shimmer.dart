import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/constants/app_curves.dart';

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
