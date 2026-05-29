import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// The one hairline divider used across the app. Three named uses:
///  * `AppDivider()`       — between list rows on a page (inset [AppSizes.lg]
///                           both sides so it never touches the screen edge).
///  * `AppDivider.flush()` — edge-to-edge; full-bleed rows / section ends.
///  * `AppDivider.inset()` — left-indented past a leading icon/avatar so the
///                           line aligns under the row's text. [leading] =
///                           icon width + gap (default 56 = 40 + 16).
///
/// Prefer flat rows + these dividers over bordered "card" containers for list
/// and section layout — it reads cleaner across screens.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = AppSizes.lg, this.endIndent = AppSizes.lg});

  /// Full-width divider with no indent.
  const AppDivider.flush({super.key}) : indent = 0, endIndent = 0;

  /// Indented past a leading icon/avatar so the line aligns under the text.
  const AppDivider.inset({super.key, double leading = 56})
      : indent = leading,
        endIndent = 0;

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.hairline,
      thickness: 1,
      height: 1,
      indent: indent,
      endIndent: endIndent,
    );
  }
}
