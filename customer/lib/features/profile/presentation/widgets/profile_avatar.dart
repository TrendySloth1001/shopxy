import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Circular profile photo. Falls back to a colored circle with the
/// user's initial when [avatarUrl] is null or empty. Used everywhere
/// the customer's identity surfaces (profile header, edit profile,
/// reviews byline, etc.) so a future swap to a different default
/// shape is one file.
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
  /// Optional ring around the avatar — used when the avatar sits on
  /// a banner / colored panel so it doesn't blend in.
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
        // While the image fetches we still show the initial-colored
        // disc so layout doesn't jump.
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : container,
        errorBuilder: (_, _, _) => container,
      ),
    );
  }
}
