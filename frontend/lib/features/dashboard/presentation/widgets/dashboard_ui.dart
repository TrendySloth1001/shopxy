import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Shared dashboard primitives — formatters, responsive breakpoints, the
/// editorial card chrome, section headers and the delta chip. Mirrors
/// `merchant-web/src/features/dashboard/components/ui.tsx`.

// ── Formatters ────────────────────────────────────────────────────────

final NumberFormat inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

final NumberFormat inrCompact = NumberFormat.compactCurrency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 1,
);

const tabularFigures = [FontFeature.tabularFigures()];

// ── Responsive breakpoints (mirror Tailwind) ──────────────────────────

class Bp {
  Bp._();
  static const double sm = 640;
  static const double md = 768;
  static const double lg = 1024;
  static const double xl = 1280;
}

/// Resolve a column count for [width] using the same prefixes the web grids
/// use. Each tier defaults to the previous one when omitted.
int responsiveCols(
  double width, {
  required int base,
  int? sm,
  int? lg,
  int? xl,
}) {
  if (xl != null && width >= Bp.xl) return xl;
  if (lg != null && width >= Bp.lg) return lg;
  if (sm != null && width >= Bp.sm) return sm;
  return base;
}

/// A responsive grid that lays children out in [columns] equal-width cells
/// with [gap] spacing — the Flutter equivalent of `grid grid-cols-N gap-md`.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.columns,
    required this.children,
    this.gap = AppSizes.md,
    this.childAspectRatio,
  });

  final int columns;
  final List<Widget> children;
  final double gap;

  /// When set, every cell is forced to this width:height ratio. When null,
  /// rows size to their tallest child (via IntrinsicHeight).
  final double? childAspectRatio;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
        i,
        (i + columns).clamp(0, children.length),
      );
      final cells = <Widget>[];
      for (var c = 0; c < columns; c++) {
        if (c > 0) cells.add(SizedBox(width: gap));
        final child = c < slice.length ? slice[c] : const SizedBox.shrink();
        cells.add(
          Expanded(
            child: childAspectRatio != null
                ? AspectRatio(aspectRatio: childAspectRatio!, child: child)
                : child,
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        childAspectRatio != null
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells)
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cells,
                ),
              ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

// ── Text styles (token-mapped) ────────────────────────────────────────

class DashText {
  DashText._();
  // Getters, not `static final`: AppColors.* are theme-aware getters, and a
  // cached `final` would freeze the ink colour at first access so dashboard
  // text wouldn't flip in dark/OLED. Re-resolving per access keeps them themed.
  static TextStyle get labelMd => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    height: 1.2,
    color: AppColors.muted,
  );
  static TextStyle get headlineMd => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.15,
    color: AppColors.black,
  );
  static TextStyle get headlineSm => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    color: AppColors.black,
  );
  static TextStyle get titleMd => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.black,
  );
  static TextStyle get bodyMd =>
      TextStyle(fontSize: 14, height: 1.4, color: AppColors.black);
  static TextStyle get bodySm =>
      TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.muted);
}

// ── Card chrome (hairline border on canvas) ───────────────────────────

class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSizes.md),
    this.radius = AppSizes.radiusLg,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = AppShapes.squircle(
      radius,
      side: BorderSide(color: AppColors.hairline),
    );
    final content = Padding(padding: padding, child: child);
    if (onTap == null) {
      return Container(
        decoration: ShapeDecoration(color: AppColors.canvas, shape: shape),
        child: content,
      );
    }
    return Material(
      color: AppColors.canvas,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Small uppercase section eyebrow.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: DashText.labelMd);
  }
}

/// A labelled section: uppercase heading with an optional trailing action,
/// then the body below.
class DashSection extends StatelessWidget {
  const DashSection({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Eyebrow(title)),
            if (action != null && onAction != null)
              GestureDetector(
                onTap: onAction,
                child: Text(
                  action!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandStrong,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        child,
      ],
    );
  }
}

/// Period-over-period delta chip — colour paired with an arrow + sign (never
/// colour alone). A null delta (no prior base) renders a neutral "New" chip.
class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, required this.value});
  final int? value;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return _pill(
        bg: AppColors.surfaceTint,
        fg: AppColors.muted,
        child: Text(
          AppLocalizations.of(context).dashboardDeltaNew,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    final v = value!;
    final up = v > 0;
    final flat = v == 0;
    final (bg, fg) = flat
        ? (AppColors.surfaceTint, AppColors.muted)
        : up
        ? (AppColors.successSoft, AppColors.success)
        : (AppColors.errorSoft, AppColors.error);
    return _pill(
      bg: bg,
      fg: fg,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!flat)
            AppIcon(
              up ? AppIcons.arrowUpwardRounded : AppIcons.arrowDownwardRounded,
              size: 12,
              color: fg,
            ),
          Text(
            '${up
                ? '+'
                : flat
                ? ''
                : '−'}${v.abs()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({required Color bg, required Color fg, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: child,
      ),
    );
  }
}

/// Navigate to a page (the Flutter equivalent of the web `<Link href>`).
void dashPush(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
}

/// Round qty for display (integers drop the decimals).
String fmtQty(double q) =>
    q.truncateToDouble() == q ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

/// Pull a usable display name from a period's enum.
String periodLabel(DashboardPeriod p) => p.label;
