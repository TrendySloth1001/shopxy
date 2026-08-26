import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';

class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({super.key, required this.email});

  final String email;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  static const int _length = 6;
  static const int _resendCooldown = 30;

  String _code = '';
  bool _isLoading = false;
  String? _error;
  int _resendIn = _resendCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendIn = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  void _onDigit(String d) {
    if (_isLoading || _code.length >= _length) return;
    setState(() {
      _code += d;
      _error = null;
    });
    if (_code.length == _length) _verify();
  }

  void _onBackspace() {
    if (_isLoading || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _verify() async {
    if (_code.length != _length || _isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().verifyEmail(widget.email, _code);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _code = '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _isLoading) return;
    final l10n = AppLocalizations.of(context);
    try {
      await context.read<AuthProvider>().resendOtp(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.otpResent)));
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _confirmLeave() async {
    if (_isLoading) return;
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final leave = await AppConfirmDialog.show(
      context,
      title: l10n.otpLeaveTitle,
      message: l10n.otpLeaveBody(widget.email),
      confirmLabel: l10n.otpLeaveDiscard,
      cancelLabel: l10n.otpLeaveStay,
      danger: true,
    );
    if (leave && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.xxl,
                    AppSizes.lg,
                    AppSizes.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.otpVerifyTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppColors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Text(
                            l10n.otpVerifySubtitle(widget.email),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: AppSizes.xxl),
                          _OtpCells(code: _code, length: _length),
                          const SizedBox(height: AppSizes.lg),
                          if (_error != null) ...[
                            AuthErrorBanner(message: _error!),
                            const SizedBox(height: AppSizes.lg),
                          ],
                          _ResendRow(
                            prompt: l10n.otpNoCodePrompt,
                            label: _resendIn > 0
                                ? l10n.otpResendIn(_resendIn)
                                : l10n.otpResend,
                            enabled: _resendIn <= 0 && !_isLoading,
                            onTap: _resend,
                          ),
                          const SizedBox(height: AppSizes.xl),
                          AuthSubmitButton(
                            label: l10n.otpVerifyCta,
                            loading: _isLoading,
                            onPressed: _code.length == _length ? _verify : null,
                          ),
                          const SizedBox(height: AppSizes.sm),
                          TextButton(
                            onPressed: _isLoading ? null : _confirmLeave,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.muted,
                            ),
                            child: Text(l10n.otpCancelSignup),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _NumericKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpCells extends StatelessWidget {
  const _OtpCells({required this.code, required this.length});
  final String code;
  final int length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < length; i++) ...[
          if (i > 0) const SizedBox(width: AppSizes.sm),
          Builder(
            builder: (_) {
              final filled = i < code.length;
              final isCursor = i == code.length;
              final active = filled || isCursor;
              return Container(
                width: 46,
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: AppColors.surface,
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: BorderSide(
                      color: active ? AppColors.brand : AppColors.hairline,
                      width: active ? 1.5 : 1,
                    ),
                  ),
                ),
                child: Text(
                  filled ? code[i] : '',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.prompt,
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final String prompt;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        TextButton(
          onPressed: enabled ? onTap : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brandStrong,
            disabledForegroundColor: AppColors.subtle,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _KeypadKey(label: d, onTap: () => onDigit(d));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.xl,
        AppSizes.sm,
        AppSizes.xl,
        AppSizes.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [digit('1'), digit('2'), digit('3')]),
          Row(children: [digit('4'), digit('5'), digit('6')]),
          Row(children: [digit('7'), digit('8'), digit('9')]),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              digit('0'),
              _KeypadKey(label: '⌫', onTap: onBackspace),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.sm),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Material(
            color: AppColors.surface,
            shape: AppShapes.squircle(
              AppSizes.radiusFull,
              side: BorderSide(color: AppColors.hairline),
            ),
            child: InkWell(
              customBorder: AppShapes.squircle(AppSizes.radiusFull),
              onTap: onTap,
              child: Center(
                child: Text(
                  label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
