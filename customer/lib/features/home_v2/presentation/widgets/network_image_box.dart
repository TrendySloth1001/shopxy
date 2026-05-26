import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

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
  /// Hard ceiling on how long we'll let `Image.network` sit on the
  /// loadingBuilder before we declare defeat. Flutter has no built-in
  /// timeout — the engine will happily hang forever on a slow CDN —
  /// so we run a parallel Timer and force the placeholder if it
  /// elapses before the frame count goes non-null.
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
            ? const Icon(
                Icons.image_outlined,
                color: AppColors.disabled,
                size: 28,
              )
            : null,
      );

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (_timedOut) {
      img = _placeholder(errorIcon: true);
    } else {
      img = Image.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        frameBuilder: (context, child, frame, _) {
          // First frame decoded → image loaded successfully, kill the
          // pending timeout so a slow display thread doesn't trigger
          // a false-positive fallback.
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
    if (widget.borderRadius != null) {
      img = ClipRRect(borderRadius: widget.borderRadius!, child: img);
    }
    return img;
  }
}

class HomeV2Img {
  HomeV2Img._();

  static String unsplash(String id, {int w = 600, int h = 600}) =>
      'https://images.unsplash.com/photo-$id?w=$w&h=$h&fit=crop&auto=format&q=70';
}
