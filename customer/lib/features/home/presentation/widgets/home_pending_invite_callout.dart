import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/invitations_page.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/widgets/invite_card.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Home-screen preview of the user's first pending invitation. Wraps
/// the shared [InviteCard] with: a tap-through to the dedicated
/// [InvitationsPage], inline accept/decline, a session-local dismiss
/// button, and a "+N more" counter when multiple invites are queued.
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

  void _openFull() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InvitationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = context.select<NotificationsProvider, List<Invitation>>(
      (p) => p.pendingIncomingForHome,
    );
    if (pending.isEmpty) return const SizedBox.shrink();

    final invite = pending.first;
    final extra = pending.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: InviteCard(
        invite: invite,
        busy: _busy,
        extraCount: extra,
        onAccept: () => _act(invite, true),
        onDecline: () => _act(invite, false),
        onTapBody: _openFull,
        onDismiss: () =>
            context.read<NotificationsProvider>().dismissFromHome(invite.id),
        reviewAllLabel:
            extra > 0 ? 'Review all ${pending.length} invitations' : null,
        onReviewAll: extra > 0 ? _openFull : null,
      ),
    );
  }
}
