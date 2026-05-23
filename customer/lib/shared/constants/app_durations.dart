/// Motion durations. Every animation in the app should use one of these.
///
/// Synced to Material 3's `MotionDurations` and the 200–300ms band that
/// feels right on a phone: too fast and feedback is unreadable, too slow
/// and the UI feels lazy.
///
/// Respect `MediaQuery.disableAnimations(context)` before using these:
/// when the OS-level Reduce Motion toggle is on, animations should
/// short-circuit to `Duration.zero`.
class AppDurations {
  AppDurations._();

  /// Micro feedback — ripples, focus rings, toggle thumb travel.
  /// Anything under 120ms reads as "instant" and is fine here.
  static const Duration micro = Duration(milliseconds: 100);

  /// Short transitions — most state changes (selection highlights,
  /// chip taps, button press feedback).
  static const Duration short = Duration(milliseconds: 180);

  /// Default for in-page changes — bottom-sheet show/hide, drawer
  /// slide, card expand. The "natural" tempo.
  static const Duration medium = Duration(milliseconds: 240);

  /// Longer reveal — hero transitions, route transitions on
  /// chromebook-class screens, expandable sections.
  static const Duration long = Duration(milliseconds: 320);

  /// Snackbar auto-dismiss. NN/g recommends 3–5s for content the user
  /// might want to read; 3s is the right balance for a single-line
  /// confirmation.
  static const Duration snackbar = Duration(seconds: 3);

  /// Toast-style messages that need a moment to read.
  static const Duration snackbarLong = Duration(seconds: 5);

  /// Debounce for type-ahead search. 220ms matches the merchant app's
  /// category picker and feels responsive without firing per keystroke.
  static const Duration searchDebounce = Duration(milliseconds: 220);
}
