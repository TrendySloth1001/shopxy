import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/invitations_page.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Sticky callout shown on the home page directly under the search bar
/// whenever the user has unanswered invitations. Lives outside the
/// scroll view so it can't be ignored by scrolling past it — the user
/// must explicitly accept, decline, or tap through to the full
/// invitations page.
class HomePendingInviteCallout extends StatefulWidget {
  const HomePendingInviteCallout({super.key});

  @override
  State<HomePendingInviteCallout> createState() =>
      _HomePendingInviteCalloutState();
}

class _HomePendingInviteCalloutState extends State<HomePendingInviteCallout> {
  bool _busy = false;

  Future<void> _act(Invitation invite, bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<NotificationsProvider>();
    final shopsProvider = context.read<ShopsProvider>();
    try {
      if (accept) {
        await provider.accept(invite.id);
        await shopsProvider.loadShops();
      } else {
        await provider.decline(invite.id);
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Invitation accepted — added to your shops.'
              : 'Invitation declined.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = context.select<NotificationsProvider, List<Invitation>>(
      (p) => p.pendingIncoming,
    );
    if (pending.isEmpty) return const SizedBox.shrink();

    final invite = pending.first;
    final userName = invite.fromUserName;
    final shopName = invite.fromShopName;
    // "Person from Shop invited you" reads more human than the old
    // "Shop invited you" — preserve graceful fallbacks for the cases
    // where the backend doesn't have both names.
    final String title;
    if (userName != null && shopName != null) {
      title = '$userName from $shopName invited you';
    } else if (shopName != null) {
      title = '$shopName invited you';
    } else if (userName != null) {
      title = '$userName invited you';
    } else {
      title = 'Someone invited you';
    }
    final extra = pending.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.md,
          AppSizes.md,
          AppSizes.md,
          AppSizes.sm + 2,
        ),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusLg,
            side: const BorderSide(color: AppColors.hairline, width: 0.8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: AppColors.brandSoft,
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: AppColors.brand,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSizes.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'NEW INVITE',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          if (extra > 0) ...[
                            const SizedBox(width: AppSizes.xs),
                            Text(
                              '+$extra more',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: -0.1,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        invite.isParty
                            ? 'Join as a customer of this shop'
                            : 'Join as a supplier to this shop',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: _GhostButton(
                    label: 'Decline',
                    onTap: _busy ? null : () => _act(invite, false),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  flex: 2,
                  child: _SolidButton(
                    label: 'Accept',
                    busy: _busy,
                    onTap: _busy ? null : () => _act(invite, true),
                  ),
                ),
              ],
            ),
            if (extra > 0) ...[
              const SizedBox(height: AppSizes.xs),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InvitationsPage(),
                    ),
                  ),
                  child: Text(
                    'Review all ${pending.length} invitations',
                    style: const TextStyle(
                      fontSize: 12,
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline, width: 1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled ? AppColors.disabled : AppColors.muted,
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
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
    return InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      onTap: onTap,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: AppColors.brand,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
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
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.white,
                    size: 16,
                  ),
                ],
              ),
      ),
    );
  }
}
