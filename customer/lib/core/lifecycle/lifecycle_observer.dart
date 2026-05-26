import 'dart:async';
import 'package:flutter/widgets.dart';

/// Top-level [AppLifecycleState] observer. Wired in [ShopxyCustomerApp]
/// so a foreground/background transition can:
///   * flush the analytics queue (avoid losing events on app kill)
///   * re-sync the cart (pick up server-side price changes / removals)
///   * trigger an opportunistic refresh of the home feed when stale
///
/// The wrapper takes plain callbacks rather than concrete provider
/// references so it doesn't pull the dependency graph into core/.
class LifecycleObserver extends StatefulWidget {
  const LifecycleObserver({
    super.key,
    required this.child,
    this.onResumed,
    this.onPaused,
  });

  final Widget child;
  final FutureOr<void> Function()? onResumed;
  final FutureOr<void> Function()? onPaused;

  @override
  State<LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends State<LifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        final cb = widget.onResumed;
        if (cb != null) cb();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        final cb = widget.onPaused;
        if (cb != null) cb();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
