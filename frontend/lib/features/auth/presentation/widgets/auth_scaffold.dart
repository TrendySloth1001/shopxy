import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Below this width the illustration panel is dropped and the form takes the
/// full width — mirrors the merchant-web auth shell.
const double _kSplitWidth = 900;

/// Signed-out scaffold that mirrors the merchant-web auth screens exactly:
/// a brand lockup + Sign in / Create account chips along the top, an
/// illustration panel on the left at wide widths that fades into the canvas,
/// and a focused, vertically-centred form column (≤ 400) on the right. On
/// phones only the form shows.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.footerPrompt,
    required this.footerCta,
    required this.onFooterTap,
    required this.onSignIn,
    required this.onCreateAccount,
    this.heroAsset = 'assets/login.png',
  });

  final String title;
  final String subtitle;

  /// The form body (fields, buttons, legal copy) for the column.
  final List<Widget> children;

  final String footerPrompt;
  final String footerCta;
  final VoidCallback onFooterTap;

  /// Header chip actions.
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  final String heroAsset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      // Keep the body (and the backdrop) full-height when the keyboard opens —
      // otherwise the Scaffold shrinks and the background image jumps/resizes.
      // The form scrolls instead (see the keyboard inset padding below).
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _kSplitWidth;
            return Stack(
              children: [
                if (wide)
                  Row(
                    children: [
                      Expanded(child: _IllustrationPanel(asset: heroAsset)),
                      Expanded(child: _formColumn(context)),
                    ],
                  )
                else
                  Stack(
                    children: [
                      const Positioned.fill(child: _PhoneBackdrop()),
                      _formColumn(context),
                    ],
                  ),
                Positioned(
                  top: AppSizes.sm,
                  left: AppSizes.lg,
                  right: AppSizes.lg,
                  child: _AuthHeader(
                    onSignIn: onSignIn,
                    onCreateAccount: onCreateAccount,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _formColumn(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        // Bottom inset grows with the keyboard so the focused field can scroll
        // clear of it (the Scaffold no longer resizes — see resizeToAvoidBottomInset).
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          80,
          AppSizes.lg,
          AppSizes.xxl + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.xxl),
              ...children,
              const SizedBox(height: AppSizes.xxl),
              Divider(color: AppColors.hairline, height: 1),
              const SizedBox(height: AppSizes.lg),
              GestureDetector(
                onTap: onFooterTap,
                behavior: HitTestBehavior.opaque,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$footerPrompt ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      TextSpan(
                        text: footerCta,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Left showcase panel — the illustration bleeding under a gradient that fades
/// to the canvas on the right so it merges into the form column.
class _IllustrationPanel extends StatelessWidget {
  const _IllustrationPanel({required this.asset});
  final String asset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: AppColors.heroPanel),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover, alignment: Alignment.center),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.canvas.withValues(alpha: 0.1),
                  AppColors.canvas.withValues(alpha: 0.4),
                  AppColors.canvas,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone-only backdrop: the boho illustration full-bleed behind the form, faded
/// into the canvas by a top→bottom gradient so the form stays readable. Because
/// the overlay is the theme-aware canvas colour, it lightens the art in light
/// mode and darkens it in dark / OLED.
class _PhoneBackdrop extends StatelessWidget {
  const _PhoneBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Boho art, softly blurred for a frosted backdrop.
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Image.asset(
            'assets/auth-boho.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        // Translucent canvas wash — lets the art read through (theme-aware) while
        // keeping the form legible. A touch denser at the bottom behind the
        // footer/links.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.canvas.withValues(alpha: 0.65),
                AppColors.canvas.withValues(alpha: 0.80),
                AppColors.canvas.withValues(alpha: 0.95),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// Top bar: brand lockup on the left, Sign in / Create account chips on the
/// right — the signed-out counterpart to the app header.
class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.onSignIn, required this.onCreateAccount});
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏪', style: TextStyle(fontSize: 26)),
            const SizedBox(width: AppSizes.sm),
            Text(
              'ShopXY',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderChip(
              icon: AppIcons.loginRounded,
              label: l10n.authSignIn,
              onTap: onSignIn,
            ),
            const SizedBox(width: AppSizes.sm),
            _HeaderChip(
              icon: AppIcons.personAddAlt1Rounded,
              label: l10n.authCreateAccount,
              filled: true,
              onTap: onCreateAccount,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final AppIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = filled ? AppColors.onInverse : AppColors.black;
    return Material(
      color: filled ? AppColors.inverseSurface : Colors.transparent,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: filled ? BorderSide.none : BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 16, color: fg),
              const SizedBox(width: AppSizes.xs),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Continue with Google" pill — surface fill, hairline border, painted 4-colour
/// Google "G". The backend Google flow isn't wired yet, so [onTap] should
/// surface a "coming soon" notice (matching merchant-web).
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: _GoogleGPainter()),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                l10n.authContinueWithGoogle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.23;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four arcs forming the ring (0°=east, clockwise): blue right, green bottom,
    // yellow left, red top. A small gap on the right is filled by the bar.
    p.color = _red;
    canvas.drawArc(rect, _rad(-135), _rad(90), false, p);
    p.color = _yellow;
    canvas.drawArc(rect, _rad(135), _rad(80), false, p);
    p.color = _green;
    canvas.drawArc(rect, _rad(55), _rad(80), false, p);
    p.color = _blue;
    canvas.drawArc(rect, _rad(-20), _rad(60), false, p);

    // The inner horizontal bar of the G (blue), pointing toward the centre.
    final bar = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.43,
        size.width * 0.48 - stroke / 2,
        size.height * 0.16,
      ),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGPainter oldDelegate) => false;
}

/// "── or continue with email ──" rule.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.hairline, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
          child: Text(
            label ?? l10n.authOrContinueWithEmail,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
        ),
        Expanded(child: Divider(color: AppColors.hairline, height: 1)),
      ],
    );
  }
}

/// Web-style field: a label above a filled, hairline-bordered input (no
/// floating label, no prefix icon). Password fields get an inline "Show / Hide"
/// text toggle on the right instead of an eye icon.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.helper,
    this.validator,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final String? helper;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _revealed = !widget.obscure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.xs, left: 2),
          child: Text(
            widget.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscure && !_revealed,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofocus: widget.autofocus,
          autocorrect: widget.autocorrect,
          textCapitalization: widget.textCapitalization,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            helperText: widget.helper,
            helperMaxLines: 2,
            suffixIcon: widget.obscure
                ? TextButton(
                    onPressed: () => setState(() => _revealed = !_revealed),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.muted,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(_revealed ? l10n.authHide : l10n.authShow),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minHeight: 0,
              minWidth: 0,
            ),
          ),
        ),
      ],
    );
  }
}

/// Brand-green pill CTA used as the primary submit on the auth screens.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null && !loading;
    return Material(
      color: enabled ? AppColors.brand : AppColors.disabled,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: 52,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFFFFFFF),
                    ),
                  )
                : Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Inline error banner — hairline error border, soft fill.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.errorSoft,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.error, width: 1),
        ),
      ),
      child: Row(
        children: [
          AppIcon(
            AppIcons.errorOutlineRounded,
            color: AppColors.error,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
