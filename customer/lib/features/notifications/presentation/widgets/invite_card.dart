import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

/// Single source of truth for "you've been invited" card rendering.
/// Used both as the home-page preview (first pending invite, optional
/// dismiss, taps through to the dedicated page) and as each row on the
/// Invitations page itself (full message + status). The visual
/// language is identical across both surfaces by design — switching
/// screens shouldn't make the user wonder if it's the same invite.
class InviteCard extends StatelessWidget {
  const InviteCard({
    super.key,
    required this.invite,
    required this.busy,
    this.actionable = true,
    this.onAccept,
    this.onDecline,
    this.onTapBody,
    this.onDismiss,
    this.extraCount = 0,
    this.reviewAllLabel,
    this.onReviewAll,
    this.showExpiry = false,
    this.showNewBadge = true,
  });

  final Invitation invite;
  final bool busy;

  /// True on the home preview + pending tab. False on the history tab,
  /// where we render a status chip instead of accept/decline buttons.
  final bool actionable;

  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  /// Tap on the body area (cover/logo/title region — not on the
  /// buttons). Wired on the home preview to push the full
  /// Invitations page. Null on the InvitationsPage itself.
  final VoidCallback? onTapBody;

  /// × button on the cover banner. Null hides the button. Home wires
  /// this to a session-local dismiss so the user can hide a noisy
  /// invite without declining it server-side.
  final VoidCallback? onDismiss;

  /// "+N more" indicator next to the NEW INVITE chip — used on the
  /// home preview when there are additional pending invites queued
  /// behind this one.
  final int extraCount;

  /// Bottom-aligned secondary link (e.g. "Review all 4 invitations").
  /// Only renders if both label and callback are provided.
  final String? reviewAllLabel;
  final VoidCallback? onReviewAll;

  /// Optional "Expires in 2 days" footnote, used on the InvitationsPage.
  final bool showExpiry;

  /// The brand-coloured NEW INVITE chip. Off on the InvitationsPage
  /// where the surrounding tab already labels the row.
  final bool showNewBadge;

  @override
  Widget build(BuildContext context) {
    final userName = invite.fromUserName;
    final shopName = invite.effectiveShopName;
    final String title;
    if (userName != null && shopName != null) {
      title = '$userName invited you to $shopName';
    } else if (userName != null) {
      title = '$userName invited you';
    } else if (shopName != null) {
      title = '$shopName invited you';
    } else {
      title = 'You have a new invitation';
    }

    final subtitle = invite.isParty
        ? 'Join as a customer of this shop'
        : 'Join as a supplier to this shop';

    final hasMessage =
        invite.message != null && invite.message!.trim().isNotEmpty;

    final card = Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: const BorderSide(color: AppColors.hairline, width: 0.8),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cover(bannerUrl: invite.shopBannerUrl, onDismiss: onDismiss),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.md,
              0,
              AppSizes.md,
              AppSizes.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Negative top to let the logo overlap the cover.
                Transform.translate(
                  offset: const Offset(0, -18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShopLogo(
                        logoUrl: invite.shopLogoUrl,
                        fallbackInitial: _initial(shopName ?? userName),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSizes.xxl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (showNewBadge) ...[
                                    _NewBadge(),
                                    const SizedBox(width: AppSizes.xs),
                                  ],
                                  if (extraCount > 0)
                                    Text(
                                      '+$extraCount more',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.muted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  if (!actionable) _StatusChip(invite: invite),
                                ],
                              ),
                              const SizedBox(height: AppSizes.sm),
                              Text(
                                title,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.black,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.1,
                                      height: 1.25,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSizes.xxs),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.xs),
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: ShapeDecoration(
                        color: AppColors.heroPanel,
                        shape: AppShapes.squircle(AppSizes.radiusSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppIcon(
                            AppIcons.formatQuoteRounded,
                            size: AppSizes.iconSm,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: AppSizes.xs),
                          Expanded(
                            child: Text(
                              invite.message!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.black,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (actionable) ...[
                  // When there's no message, pull the buttons up a touch
                  // so the negative-offset title row doesn't leave a
                  // visual gap. When a message is present, leave the
                  // buttons in their natural slot — pulling them up
                  // would overlap the message bubble.
                  Padding(
                    padding: EdgeInsets.only(top: hasMessage ? AppSizes.md : 0),
                    child: Transform.translate(
                      offset: hasMessage ? Offset.zero : const Offset(0, -10),
                      child: Row(
                        children: [
                          Expanded(
                            child: _GhostButton(
                              label: 'Decline',
                              onTap: busy ? null : onDecline,
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            flex: 2,
                            child: _SolidButton(
                              label: 'Accept',
                              busy: busy,
                              onTap: busy ? null : onAccept,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (showExpiry)
                  Padding(
                    padding: EdgeInsets.only(top: actionable ? 0 : AppSizes.sm),
                    child: Text(
                      'Expires ${_formatExpiry(invite.expiresAt)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (reviewAllLabel != null && onReviewAll != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, AppSizes.xxl),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onReviewAll,
                      child: Text(
                        reviewAllLabel!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTapBody == null) return card;
    // Whole card is tappable when wired, but the embedded buttons
    // (Decline/Accept) intercept their own taps because they're
    // Material InkWells higher in the hit-test stack.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapBody,
      child: card,
    );
  }

  static String _initial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name.trim().substring(0, 1).toUpperCase();
  }

  static String _formatExpiry(DateTime t) {
    final diff = t.difference(DateTime.now());
    if (diff.isNegative) return 'expired';
    if (diff.inDays >= 2) return 'in ${diff.inDays} days';
    if (diff.inHours >= 2) return 'in ${diff.inHours} hours';
    return 'soon';
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.bannerUrl, required this.onDismiss});
  final String? bannerUrl;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final hasBanner = bannerUrl != null && bannerUrl!.isNotEmpty;
    return SizedBox(
      height: 86,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasBanner
                ? NetworkImageBox(url: resolveImageUrl(bannerUrl!))
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.brandSoft, AppColors.heroPanel],
                      ),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSizes.lg),
                    child: const AppIcon(
                      AppIcons.storefrontRounded,
                      color: AppColors.brand,
                      size: AppSizes.iconXl,
                    ),
                  ),
          ),
          // Subtle bottom gradient so the logo + text reads cleanly
          // even when the banner is photographic.
          if (hasBanner)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.black.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),
          if (onDismiss != null)
            Positioned(
              top: AppSizes.sm,
              right: AppSizes.sm,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: Container(
                  width: AppSizes.xxl,
                  height: AppSizes.xxl,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const AppIcon(
                    AppIcons.closeRounded,
                    color: AppColors.white,
                    size: AppSizes.iconSm,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.logoUrl, required this.fallbackInitial});
  final String? logoUrl;
  final String fallbackInitial;

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: AppSizes.avatarMd,
      height: AppSizes.avatarMd,
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline, width: 0.8),
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipRRect(
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
        child: hasLogo
            ? NetworkImageBox(url: resolveImageUrl(logoUrl!))
            : Container(
                color: AppColors.brandSoft,
                alignment: Alignment.center,
                child: Text(
                  fallbackInitial,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: AppColors.brand,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Text(
        'NEW INVITE',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.invite});
  final Invitation invite;

  @override
  Widget build(BuildContext context) {
    final (label, color, soft) = switch (invite.status) {
      InviteStatus.accepted => (
        'Accepted',
        AppColors.success,
        AppColors.successSoft,
      ),
      InviteStatus.declined => (
        'Declined',
        AppColors.muted,
        AppColors.heroPanel,
      ),
      InviteStatus.cancelled => (
        'Cancelled',
        AppColors.muted,
        AppColors.heroPanel,
      ),
      InviteStatus.expired => (
        'Expired',
        AppColors.warning,
        AppColors.warningSoft,
      ),
      InviteStatus.pending => ('Pending', AppColors.info, AppColors.infoSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 3),
      decoration: ShapeDecoration(
        color: soft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Container(
          height: AppSizes.huge,
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: disabled ? AppColors.disabled : AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brand,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Container(
          height: AppSizes.huge,
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: AppSizes.iconSm,
                  height: AppSizes.iconSm,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    const AppIcon(
                      AppIcons.arrowForwardRounded,
                      color: AppColors.white,
                      size: AppSizes.iconSm,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
