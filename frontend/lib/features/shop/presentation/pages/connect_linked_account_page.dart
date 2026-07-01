import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final d = _details;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(l10n.shopConnectExistingAccountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.xl),
        children: [
          Text(
            l10n.shopConnectIntro,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.lg),
          TextField(
            controller: _idCtrl,
            autofocus: true,
            enabled: !_busy && d == null,
            onChanged: (_) => setState(() => _details = null),
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: InputDecoration(
              labelText: l10n.shopConnectAccountIdLabel,
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
                  : Text(l10n.shopConnectVerify),
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
                  Text(l10n.shopConnectConfirmTitle,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSizes.md),
                  _Fact(label: l10n.shopConnectFactAccount, value: d.accountId),
                  _Fact(label: l10n.shopConnectFactBusiness, value: d.legalBusinessName ?? '—'),
                  _Fact(label: l10n.shopConnectFactContact, value: d.contactName ?? '—'),
                  _Fact(label: l10n.shopConnectFactEmail, value: d.email ?? '—'),
                  _Fact(label: l10n.shopConnectFactKycStatus, value: d.kycStatus),
                  _Fact(label: l10n.shopConnectFactPayouts, value: d.payoutsEnabled ? l10n.shopEnabled : l10n.shopNotYetEnabled),
                  if (!d.payoutsEnabled) ...[
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      l10n.shopConnectPayoutsNotEnabledWarning,
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
                        : Text(l10n.shopConnectLinkAccount),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _details = null),
                  child: Text(l10n.shopCancel),
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
