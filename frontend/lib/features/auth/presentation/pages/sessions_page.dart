import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// "Devices & sessions" — where the account is signed in, with the ability to
/// sign out an individual device (revokes its session immediately) or every
/// other device at once. Backed by /auth/sessions.
class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  late Future<List<SessionInfo>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SessionInfo>> _load() =>
      context.read<AuthProvider>().listSessions();

  Future<void> _refresh() async {
    final f = _load();
    // NB: a block body, not `setState(() => _future = f)`. The arrow form
    // returns the assignment's value (a Future), which Flutter rejects as an
    // "async setState callback" and throws — crashing the screen on refresh.
    setState(() {
      _future = f;
    });
    await f;
  }

  Future<void> _revoke(SessionInfo s) async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<AuthProvider>().revokeSession(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sessionsSignedOut)));
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeOthers() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<AuthProvider>().revokeOtherSessions();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sessionsSignedOut)));
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.profileDevicesSessions),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.brand,
        backgroundColor: AppColors.surface,
        child: FutureBuilder<List<SessionInfo>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return AppErrorView(onRetry: _refresh);
            }
            final sessions = snap.data ?? const <SessionInfo>[];
            final others = sessions.where((s) => !s.current).length;
            final topInset = FloatingAppBar.contentTopInset(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSizes.lg,
                topInset + AppSizes.sm,
                AppSizes.lg,
                FloatingBottomNav.contentBottomInset(context) + AppSizes.sm,
              ),
              children: [
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.xxxl),
                    child: Center(
                      child: Text(
                        l10n.sessionsEmpty,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  )
                else
                  for (final s in sessions) ...[
                    _SessionCard(
                      session: s,
                      busy: _busy,
                      onRevoke: () => _revoke(s),
                    ),
                    const SizedBox(height: AppSizes.sm),
                  ],
                if (others > 0) ...[
                  const SizedBox(height: AppSizes.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _revokeOthers,
                      icon: AppIcon(
                        AppIcons.logoutRounded,
                        size: AppSizes.iconSm,
                        color: AppColors.error,
                      ),
                      label: Text(l10n.sessionsSignOutOthers),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.hairline),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.md,
                        ),
                        shape: AppShapes.squircle(AppSizes.radiusFull),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  final SessionInfo session;
  final bool busy;
  final VoidCallback onRevoke;

  bool get _isPhone {
    final d = session.device.toLowerCase();
    return d.contains('app') ||
        d.contains('iphone') ||
        d.contains('ipad') ||
        d.contains('android');
  }

  String _relative(AppLocalizations l10n, DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    return l10n.timeDaysAgo(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final when = session.lastUsedAt ?? session.createdAt;
    final meta = [
      if (session.where != null) session.where!,
      l10n.sessionsLastActive(_relative(l10n, when)),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.huge,
            height: AppSizes.huge,
            decoration: ShapeDecoration(
              color: AppColors.surfaceTint,
              shape: AppShapes.squircle(AppSizes.radiusMd),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              _isPhone ? AppIcons.smartphoneRounded : AppIcons.computerRounded,
              color: AppColors.black,
              size: AppSizes.iconLg,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.device,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (session.current) ...[
                      const SizedBox(width: AppSizes.sm),
                      _CurrentChip(label: l10n.sessionsThisDevice),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          // Only non-current sessions can be signed out here (revoking the
          // current one would log you out — use logout for that).
          if (!session.current)
            TextButton(
              onPressed: busy ? null : onRevoke,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.xs,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.sessionsSignOut),
            ),
        ],
      ),
    );
  }
}

class _CurrentChip extends StatelessWidget {
  const _CurrentChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xxs,
      ),
      decoration: ShapeDecoration(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.brandStrong,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
