import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/network/offline/network_status.dart';
import 'package:shopxy/core/network/offline/outbox.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(bottom: false, child: _StatusPill()),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offline = context.select<NetworkStatus, bool>((n) => n.offline);
    final outbox = context.read<Outbox?>();

    return ValueListenableBuilder<int>(
      valueListenable: outbox?.pendingCount ?? _zero,
      builder: (context, pending, _) {
        final String? message;
        final AppIconData icon;
        if (offline) {
          message = l10n.offlineBannerMessage;
          icon = AppIcons.cloudOffRounded;
        } else if (pending > 0) {
          message = l10n.offlineSyncingMessage(pending);
          icon = AppIcons.syncRounded;
        } else {
          message = null;
          icon = AppIcons.cloudOffRounded;
        }
        return _OfflinePill(message: message, icon: icon);
      },
    );
  }
}

final ValueNotifier<int> _zero = ValueNotifier<int>(0);

class _OfflinePill extends StatelessWidget {
  const _OfflinePill({required this.message, required this.icon});
  final String? message;
  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    final visible = message != null;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : const Offset(0, -1.4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.sm),
            child: Center(
              child: ClipRRect(
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.sm,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.inverseSurface.withValues(alpha: 0.9),
                      shape: AppShapes.squircle(
                        AppSizes.radiusFull,
                        side: BorderSide(color: AppColors.hairline),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          icon,
                          size: AppSizes.iconSm,
                          color: AppColors.onInverse,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          message ?? '',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.onInverse,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
