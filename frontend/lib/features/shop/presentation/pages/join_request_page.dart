import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/shop/data/team_service.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Shown right after login/registration when the account has been
/// invited onto a shop's team but isn't a member yet. Lays out the
/// inviting shop, the offered role, and exactly what that role can and
/// can't do — so the person knows their responsibilities before they
/// accept. Accept makes them staff (and the auth gate then drops them
/// into the merchant app); decline / "not now" signs them out.
class JoinRequestPage extends StatefulWidget {
  const JoinRequestPage({
    super.key,
    required this.invite,
    required this.onResolved,
  });

  /// The pending TEAM invitation to act on.
  final Invitation invite;

  /// Called after the invite is accepted (membership created) so the
  /// caller can refresh the session + re-route into the app.
  final Future<void> Function() onResolved;

  @override
  State<JoinRequestPage> createState() => _JoinRequestPageState();
}

class _JoinRequestPageState extends State<JoinRequestPage> {
  late final InvitationsRemoteDataSource _invites;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _invites = InvitationsRemoteDataSource(context.read<ApiClient>());
  }

  String get _roleLabel => widget.invite.teamRoleName ?? 'Staff';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await _invites.accept(widget.invite.id);
      // Membership created server-side; refresh /auth/me so shopRole is
      // populated and the auth gate routes into the app.
      await widget.onResolved();
    } catch (e) {
      _snack(friendlyError(e));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await _invites.decline(widget.invite.id);
    } catch (_) {
      // Even if the decline call fails, fall through to sign-out — the
      // account has no shop, so there's nothing for it to do here.
    }
    if (!mounted) return;
    await context.read<AuthProvider>().logout();
  }

  Future<void> _notNow() async {
    if (_busy) return;
    await context.read<AuthProvider>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inv = widget.invite;
    final shop = inv.fromShopName ?? inv.fromUserName ?? 'A shop';
    final responsibilities =
        responsibilitiesFromPermissions(inv.teamPermissions);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _busy ? null : _notNow,
            child: const Text('Not now'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.huge),
          children: [
            Container(
              width: AppSizes.massive,
              height: AppSizes.massive,
              decoration: BoxDecoration(
                color: AppColors.tileBg(AppColors.brandSoft),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.groups_rounded,
                  color: AppColors.brandStrong, size: AppSizes.iconXl),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              "You're invited to join",
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 2),
            Text(
              shop,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Text('as a ',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: AppColors.muted)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md, vertical: AppSizes.xs),
                  decoration: ShapeDecoration(
                    color: AppColors.tileBg(AppColors.brandSoft),
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                  ),
                  child: Text(
                    _roleLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.brandStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (inv.message != null && inv.message!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSizes.lg),
              Material(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: Text('“${inv.message!.trim()}”',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic)),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.xl),
            Text(
              'WHAT YOU\'LL BE ABLE TO DO',
              style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6),
            ),
            const SizedBox(height: AppSizes.sm),
            Material(
              color: AppColors.surface,
              shape: AppShapes.squircle(AppSizes.radiusMd),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Column(
                  children: [
                    if (responsibilities.isEmpty)
                      const _ResponsibilityRow(
                        text: 'Limited access — ask the owner for details.',
                        denied: true,
                      ),
                    for (final r in responsibilities)
                      _ResponsibilityRow(text: r, denied: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _accept,
                child: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.onInverse)),
                      )
                    : Text('Join ${shop.length > 18 ? 'the team' : shop}'),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : _decline,
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Decline invitation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsibilityRow extends StatelessWidget {
  const _ResponsibilityRow({required this.text, required this.denied});
  final String text;
  final bool denied;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            denied ? Icons.block_rounded : Icons.check_circle_rounded,
            size: 18,
            color: denied ? AppColors.subtle : AppColors.success,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: denied ? AppColors.muted : AppColors.black,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
