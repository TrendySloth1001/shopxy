import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/shop/data/datasources/linked_account_remote_data_source.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Connect an EXISTING Razorpay linked account by its acc_XXXX id — skips the
/// 4-step KYC wizard. Enter the id → verify (fetch from Razorpay) → confirm the
/// fetched details → link. Pops `true` on success so the caller can refresh.
class ConnectLinkedAccountPage extends StatefulWidget {
  const ConnectLinkedAccountPage({super.key});

  @override
  State<ConnectLinkedAccountPage> createState() => _ConnectLinkedAccountPageState();
}

class _ConnectLinkedAccountPageState extends State<ConnectLinkedAccountPage> {
  late final LinkedAccountRemoteDataSource _ds;
  final _idCtrl = TextEditingController();
  ConnectAccountDetails? _details;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ds = LinkedAccountRemoteDataSource(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  bool get _idValid => RegExp(r'^acc_[A-Za-z0-9]+$').hasMatch(_idCtrl.text.trim());

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final d = await _ds.verifyConnect(_idCtrl.text.trim());
      if (!mounted) return;
      setState(() => _details = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _ds.confirmConnect(_idCtrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _details;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Connect existing account')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.xl),
        children: [
          Text(
            'Already have a Razorpay linked account? Paste its id to link it — no '
            'need to re-do KYC.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.lg),
          TextField(
            controller: _idCtrl,
            autofocus: true,
            enabled: !_busy && d == null,
            onChanged: (_) => setState(() => _details = null),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: const InputDecoration(
              labelText: 'Account id',
              hintText: 'acc_XXXXXXXXXXXX',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSizes.md),
            Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSizes.lg),
          if (d == null)
            FilledButton(
              onPressed: _idValid && !_busy ? _verify : null,
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Verify'),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confirm this is your account',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSizes.md),
                  _Fact(label: 'Account', value: d.accountId),
                  _Fact(label: 'Business', value: d.legalBusinessName ?? '—'),
                  _Fact(label: 'Contact', value: d.contactName ?? '—'),
                  _Fact(label: 'Email', value: d.email ?? '—'),
                  _Fact(label: 'KYC status', value: d.kycStatus),
                  _Fact(label: 'Payouts', value: d.payoutsEnabled ? 'Enabled' : 'Not yet enabled'),
                  if (!d.payoutsEnabled) ...[
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      'Payouts aren\'t enabled yet — you can link it, but UPI at the till '
                      'stays off until Razorpay activates the account.',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _confirm,
                    child: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Link this account'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _details = null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.black)),
          ),
        ],
      ),
    );
  }
}
