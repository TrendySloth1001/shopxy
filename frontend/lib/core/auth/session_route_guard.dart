import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';

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
    if (_wasAuthenticated && !signedIn && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _wasAuthenticated = signedIn;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
