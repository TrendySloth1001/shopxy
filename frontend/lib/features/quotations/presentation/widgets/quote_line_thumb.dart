import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Small squircle thumbnail for a quotation line — uses the stored line image
/// when present, falling back to a brand-tinted box icon. Quote lines only
/// carry a name + url (not a full Product), so this is lighter than
/// [ProductThumbnail].
class QuoteLineThumb extends StatelessWidget {
  const QuoteLineThumb({super.key, required this.imageUrl, this.size = AppSizes.avatarSm});
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl ?? '';
    final shape = AppShapes.squircle(AppSizes.radiusSm);
    if (raw.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(color: AppColors.tileBg(AppColors.brandSoft), shape: shape),
        alignment: Alignment.center,
        child: Icon(AppIcons.inventory2Outlined,
            size: AppSizes.iconMd, color: AppColors.brand),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(color: AppColors.surface, shape: shape),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: CachedNetworkImage(
          imageUrl: resolveImageUrl(raw),
          fit: BoxFit.cover,
          placeholder: (_, _) => Container(color: AppColors.heroPanel),
          errorWidget: (_, _, _) => Container(
            color: AppColors.tileBg(AppColors.brandSoft),
            alignment: Alignment.center,
            child: Icon(AppIcons.inventory2Outlined,
                size: AppSizes.iconMd, color: AppColors.brand),
          ),
        ),
      ),
    );
  }
}
