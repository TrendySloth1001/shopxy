import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';

/// Unwinds the navigation stack the moment a session ends.
///
/// The auth gate decides what the *home* route is, and every screen reached
/// from the shell (Settings, Profile, POS, a product detail…) is pushed on top
/// of it. So swapping home back to the login screen on logout changes nothing
/// the user can see: they stay on Settings, with the login screen hidden
/// underneath, apparently still signed in. Popping to the first route reveals
/// it.
///
/// This listens for the transition rather than living at each logout button
/// because the session can also end without one — [AuthProvider.clearAuth]
/// fires when a token refresh fails, and an expiry deep inside the app has
/// exactly the same problem. One listener covers every cause, including the
/// ones added later.
///
/// Mount it as (or just under) the home route, so its context resolves to the
/// root navigator — the one holding the pushed routes.
class SessionRouteGuard extends StatefulWidget {
  const SessionRouteGuard({super.key, required this.child});

  final Widget child;

  @override
  State<SessionRouteGuard> createState() => _SessionRouteGuardState();
}

class _SessionRouteGuardState extends State<SessionRouteGuard> {
  late final AuthProvider _auth;
  late bool _wasAuthenticated;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _wasAuthenticated = _auth.isAuthenticated;
    _auth.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    final signedIn = _auth.isAuthenticated;
    // Only the signed-in → signed-out edge. Firing on every notification would
    // pop the stack during ordinary profile refreshes.
    if (_wasAuthenticated && !signedIn && mounted) {
      // Dialogs and bottom sheets are routes too, so this dismisses them as
      // well — one left floating over the login screen is its own bug.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _wasAuthenticated = signedIn;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
