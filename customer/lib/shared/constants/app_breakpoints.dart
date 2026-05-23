/// Responsive breakpoints. The customer app is phone-first, but tablet
/// + foldable + landscape orientations exist — these are the cutoffs
/// where layout should adapt.
///
/// Values match Material 3's window-size classes (compact / medium /
/// expanded) so widgets that switch on these align with what platform
/// components do automatically.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below this width, treat the layout as compact (phone portrait).
  static const double phone = 600;

  /// Below this, medium (small tablet / phone landscape).
  static const double tablet = 840;

  /// Above this, expanded (large tablet / desktop / TV).
  static const double desktop = 1200;

  /// Maximum readable content width for body copy. Anything wider and
  /// line length crosses NN/g's 60–75 character sweet spot.
  static const double contentMaxWidth = 720;

  /// Maximum width for forms (sign-in, address, checkout). Keeps the
  /// fields in a comfortable column even on a wide screen.
  static const double formMaxWidth = 520;
}
