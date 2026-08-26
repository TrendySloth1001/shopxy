import 'dart:async';
import 'package:flutter/widgets.dart';

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
