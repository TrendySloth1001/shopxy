import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/gst/presentation/providers/gst_profile_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/widgets/app_text_field.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class GstDetailsPage extends StatefulWidget {
  const GstDetailsPage({super.key});

  @override
  State<GstDetailsPage> createState() => _GstDetailsPageState();
}

class _GstDetailsPageState extends State<GstDetailsPage> {
  final _gstin = TextEditingController();
  final _legalName = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<GstProfileProvider>();
      if (!provider.isLoaded) await provider.load();
      if (!mounted) return;
      _gstin.text = provider.profile.gstin ?? '';
      _legalName.text = provider.profile.legalName ?? '';
      setState(() {});
    });
  }

  @override
  void dispose() {
    _gstin.dispose();
    _legalName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final gstin = _gstin.text.trim();
    final legalName = _legalName.text.trim();
    if (gstin.isEmpty) {
      setState(() => _error = 'Enter your GSTIN, or remove it to go back to '
          'personal invoices.');
      return;
    }
    if (legalName.isEmpty) {
      setState(() => _error = 'Enter the business name registered against '
          'this GSTIN.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final failure = await context.read<GstProfileProvider>().save(
      gstin: gstin,
      legalName: legalName,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      setState(() => _error = failure);
      return;
    }
    showAppSnackbar(
      context,
      message: 'GST details saved',
      tone: AppSnackbarTone.success,
    );
    Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Remove GST details?',
      message: 'New orders will be invoiced to you personally, with no input '
          'credit. Invoices already issued are unaffected.',
      confirmLabel: 'Remove',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final failure = await context.read<GstProfileProvider>().save(gstin: null);
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure != null) {
      setState(() => _error = failure);
      return;
    }
    _gstin.clear();
    _legalName.clear();
    showAppSnackbar(context, message: 'GST details removed');
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GstProfileProvider>();
    final hasSaved = provider.profile.isComplete;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(
        title: 'GST details',
        subtitle: 'Claim input credit on business purchases',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            const _ExplainerCard(),
            const SizedBox(height: AppSizes.lg),
            AppTextField(
              key: const Key('gst-gstin-field'),
              controller: _gstin,
              label: 'GSTIN',
              hint: '27ABCDE1234F1Z5',
              helper: '15 characters, from your registration certificate.',
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                TextInputFormatter.withFunction(
                  (_, next) => next.copyWith(text: next.text.toUpperCase()),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
            AppTextField(
              key: const Key('gst-legal-name-field'),
              controller: _legalName,
              label: 'Registered business name',
              helper: 'Exactly as registered against this GSTIN — it is what '
                  'appears on the invoice.',
              textCapitalization: TextCapitalization.words,
              maxLength: 200,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.md),
              Text(
                _error!,
                key: const Key('gst-error'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSizes.xl),
            AppButton.primary(
              key: const Key('gst-save'),
              label: 'Save GST details',
              onPressed: _saving ? null : _save,
              isLoading: _saving,
              fullWidth: true,
            ),
            if (hasSaved) ...[
              const SizedBox(height: AppSizes.md),
              AppButton.ghost(
                key: const Key('gst-remove'),
                label: 'Remove GST details',
                onPressed: _saving ? null : _remove,
                fullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExplainerCard extends StatelessWidget {
  const _ExplainerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(
            AppIcons.receiptLongOutlined,
            size: AppSizes.iconMd,
            color: AppColors.brand,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buying for a business?',
                  style: theme.textTheme.bodyMedium?.extraBold,
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  'Save your GSTIN and you can ask for a tax invoice in your '
                  "business's name at checkout. Only sellers registered under "
                  'GST can issue one.',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
