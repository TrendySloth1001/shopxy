import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

/// How the customer says they'll move the money. There's no payment gateway
/// yet — the transfer happens off-platform and the merchant confirms receipt,
/// so this is a declared method + reference, not a live charge.
const List<String> _kModes = ['RTGS', 'NEFT', 'UPI', 'CHEQUE', 'CASH', 'OTHER'];

/// Bottom sheet: the customer offers to post a caution deposit to the shop.
/// [basket] (optional) is read-only context — the products they browsed to
/// size the deposit; [suggestedAmount] pre-fills the amount field.
/// Returns true when a request was created.
Future<bool?> showPostCautionSheet({
  required BuildContext context,
  required LinkedShop shop,
  List<Map<String, dynamic>>? basket,
  double? basketValue,
  double? suggestedAmount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    useSafeArea: true,
    shape: AppShapes.squircleTop(AppSizes.radiusXl),
    builder: (_) => _Sheet(
      shop: shop,
      basket: basket,
      basketValue: basketValue,
      suggestedAmount: suggestedAmount,
    ),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({
    required this.shop,
    this.basket,
    this.basketValue,
    this.suggestedAmount,
  });
  final LinkedShop shop;
  final List<Map<String, dynamic>>? basket;
  final double? basketValue;
  final double? suggestedAmount;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  String _mode = 'RTGS';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.suggestedAmount;
    if (s != null && s > 0) {
      _amountCtrl.text = s % 1 == 0 ? s.toStringAsFixed(0) : s.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<ShopsProvider>().submitCautionRequest(
            widget.shop,
            amount: amount,
            mode: _mode,
            modeReference: _refCtrl.text.trim(),
            note: _noteCtrl.text.trim(),
            basket: widget.basket,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    AppStrings.cautionPostCta,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.lg,
              ),
              children: [
                Text(
                  'Posting to ${widget.shop.shopName ?? widget.shop.name}. The shop '
                  'confirms once the transfer is received.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                if (widget.basket != null && widget.basket!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.md),
                  Row(
                    children: [
                      const Icon(Icons.shopping_basket_outlined,
                          size: AppSizes.iconMd, color: AppColors.brand),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          'Against ${widget.basket!.length} item(s)'
                          '${widget.basketValue != null ? ' · ${AppFormat.rupees(widget.basketValue!)} intended' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  const Divider(height: 1, color: AppColors.hairline),
                ],
                const SizedBox(height: AppSizes.lg),
                const _SectionLabel('Amount'),
                TextField(
                  controller: _amountCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: _dec(
                    prefixText: '${AppStrings.currencySymbol} ',
                    hint: '0',
                  ),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSizes.lg),
                const _SectionLabel('How you\'re paying'),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    for (final m in _kModes)
                      _ModeChip(
                        label: m,
                        selected: _mode == m,
                        onTap: () => setState(() => _mode = m),
                      ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                const _SectionLabel('Reference (UTR / cheque no.)'),
                TextField(
                  controller: _refCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _dec(hint: 'Optional but helps the shop match it'),
                ),
                const SizedBox(height: AppSizes.lg),
                const _SectionLabel('Note (optional)'),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: _dec(hint: 'Anything the shop should know'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: AppSizes.iconMd,
                        height: AppSizes.iconMd,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        'Send request',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dec({String? hint, String? prefixText}) => InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.sm),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
        ),
      );
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.black : AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(color: selected ? AppColors.black : AppColors.hairline),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? AppColors.white : AppColors.black,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

/// Opens the sheet and toasts on success, then runs [onSubmitted].
Future<void> openPostCaution(
  BuildContext context, {
  required LinkedShop shop,
  VoidCallback? onSubmitted,
}) async {
  final ok = await showPostCautionSheet(context: context, shop: shop);
  if (ok != true || !context.mounted) return;
  showAppSnackbar(
    context,
    message: AppStrings.cautionRequestSent,
    tone: AppSnackbarTone.success,
  );
  onSubmitted?.call();
}
