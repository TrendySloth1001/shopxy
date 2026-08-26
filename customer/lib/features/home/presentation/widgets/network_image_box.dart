import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class NetworkImageBox extends StatefulWidget {
  const NetworkImageBox({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderColor,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;

  @override
  State<NetworkImageBox> createState() => _NetworkImageBoxState();
}

class _NetworkImageBoxState extends State<NetworkImageBox> {
  static const _kImageTimeout = Duration(seconds: 10);

  Timer? _timeoutTimer;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _armTimeout();
  }

  @override
  void didUpdateWidget(covariant NetworkImageBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _timedOut = false;
      _armTimeout();
    }
  }

  void _armTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_kImageTimeout, () {
      if (!mounted || _timedOut) return;
      setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Widget _placeholder({bool errorIcon = false}) => Container(
    width: widget.width,
    height: widget.height,
    color: widget.placeholderColor ?? AppColors.heroPanel,
    alignment: errorIcon ? Alignment.center : null,
    child: errorIcon
        ? const AppIcon(
            AppIcons.imageOutlined,
            color: AppColors.disabled,
            size: 28,
          )
        : null,
  );

  int? _decodeWidth(BuildContext context, double logicalWidth) {
    if (!logicalWidth.isFinite || logicalWidth <= 0) return null;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final target = logicalWidth * dpr;
    const bucket = 64.0;
    return ((target / bucket).ceil() * bucket).round();
  }

  Widget _image(BuildContext context, double logicalWidth) {
    return Image.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: _decodeWidth(context, logicalWidth),
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, _) {
        if (frame != null) _timeoutTimer?.cancel();
        return child;
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          _timeoutTimer?.cancel();
          return child;
        }
        return _placeholder();
      },
      errorBuilder: (context, error, stack) {
        _timeoutTimer?.cancel();
        return _placeholder(errorIcon: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (_timedOut) {
      img = _placeholder(errorIcon: true);
    } else if (widget.width != null) {
      img = _image(context, widget.width!);
    } else {
      img = LayoutBuilder(
        builder: (context, constraints) =>
            _image(context, constraints.maxWidth),
      );
    }
    if (widget.borderRadius != null) {
      img = ClipRRect(borderRadius: widget.borderRadius!, child: img);
    }
    return RepaintBoundary(child: img);
  }
}

class HomeImg {
  HomeImg._();

  static String unsplash(String id, {int w = 600, int h = 600}) =>
      'https://images.unsplash.com/photo-$id?w=$w&h=$h&fit=crop&auto=format&q=70';
}
