import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/shared/widgets/app_pill_button.dart';

class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({super.key, required this.email});

  final String email;

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  static const int _length = 6;
  static const int _resendCooldown = 30;

  final _controller = TextEditingController();
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
    _controller.dispose();
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

  void _onChanged(String v) {
    setState(() => _error = null);
    if (v.length == _length) _verify();
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != _length || _isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().verifyEmail(widget.email, code);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _controller.clear();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0 || _isLoading) return;
    try {
      await context.read<AuthProvider>().resendOtp(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('We sent a new code.')));
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _confirmLeave() async {
    if (_isLoading) return;
    final navigator = Navigator.of(context);
    final leave = await AppConfirmDialog.show(
      context,
      title: 'Discard sign-up?',
      message:
          "Your account hasn't been created yet. If you leave now, the code "
          'sent to ${widget.email} stops working and you\'ll need to start '
          'again.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep going',
      danger: true,
    );
    if (leave && navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.xl,
                    AppSizes.xxl,
                    AppSizes.xl,
                    AppSizes.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LAST STEP',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        'Check your\nemail',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'We sent a 6-digit code to ${widget.email}. Enter it '
                        'to finish creating your account.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSizes.xxl),
                      TextField(
                        controller: _controller,
                        autofocus: true,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: _length,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(_length),
                        ],
                        onChanged: _onChanged,
                        onSubmitted: (_) => _verify(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 10,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: '------',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      Row(
                        children: [
                          Text(
                            "Didn't get it?",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextButton(
                            onPressed: (_resendIn > 0 || _isLoading)
                                ? null
                                : _resend,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brandStrong,
                              disabledForegroundColor: AppColors.muted,
                            ),
                            child: Text(
                              _resendIn > 0
                                  ? 'Resend in ${_resendIn}s'
                                  : 'Resend code',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.xl,
                  0,
                  AppSizes.xl,
                  AppSizes.md,
                ),
                child: Column(
                  children: [
                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: AppSizes.md),
                    ],
                    AppPillButton(
                      label: 'Verify and create account',
                      loading: _isLoading,
                      onPressed: _verify,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    TextButton(
                      onPressed: _isLoading ? null : _confirmLeave,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
                      child: const Text('Cancel sign-up'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
