import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = AppSizes.avatarMd,
    this.borderColor,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final Color? borderColor;

  String get _initial =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    final container = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: TextStyle(
          color: AppColors.brandStrong,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (avatarUrl == null || avatarUrl!.isEmpty) return container;
    return ClipOval(
      child: Image.network(
        resolveImageUrl(avatarUrl!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : container,
        errorBuilder: (_, _, _) => container,
      ),
    );
  }
}
