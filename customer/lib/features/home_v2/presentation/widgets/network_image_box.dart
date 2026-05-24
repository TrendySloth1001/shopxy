import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class NetworkImageBox extends StatelessWidget {
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
  Widget build(BuildContext context) {
    Widget img = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: placeholderColor ?? AppColors.heroPanel,
        );
      },
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        color: placeholderColor ?? AppColors.heroPanel,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          color: AppColors.disabled,
          size: 28,
        ),
      ),
    );
    if (borderRadius != null) {
      img = ClipRRect(borderRadius: borderRadius!, child: img);
    }
    return img;
  }
}

class HomeV2Img {
  HomeV2Img._();

  static String unsplash(String id, {int w = 600, int h = 600}) =>
      'https://images.unsplash.com/photo-$id?w=$w&h=$h&fit=crop&auto=format&q=70';
}
