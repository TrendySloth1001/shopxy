import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/coupons/data/datasources/merchant_coupons_remote_data_source.dart';
import 'package:shopxy/features/coupons/domain/merchant_coupon.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Bottom-sheet editor for creating or updating a single coupon.
/// Returns `true` to the caller iff the save succeeded so the list can
/// refresh; null otherwise.
Future<bool?> showCouponEditorSheet({
  required BuildContext context,
  MerchantCoupon? existing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
    builder: (_) => _CouponEditorSheet(existing: existing),
  );
}

class _CouponEditorSheet extends StatefulWidget {
  const _CouponEditorSheet({this.existing});
  final MerchantCoupon? existing;

  @override
  State<_CouponEditorSheet> createState() => _CouponEditorSheetState();
}

class _CouponEditorSheetState extends State<_CouponEditorSheet> {
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _discountValue;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _minOrder;
  late final TextEditingController _perUserLimit;
  late final TextEditingController _totalCap;

  String _discountType = 'PERCENT';
  late DateTime _validFrom;
  late DateTime _validUntil;
  bool _isActive = true;
  bool _isPublic = false;
  bool _firstOrderOnly = false;
  bool _saving = false;
  String? _error;

  static final _date = DateFormat('d MMM y');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _code = TextEditingController(text: e?.code ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _discountValue =
        TextEditingController(text: e?.discountValue.toStringAsFixed(0) ?? '');
    _maxDiscount = TextEditingController(
        text: e?.maxDiscount != null ? e!.maxDiscount!.toStringAsFixed(0) : '');
    _minOrder = TextEditingController(
        text: e?.minOrderAmount.toStringAsFixed(0) ?? '0');
    _perUserLimit = TextEditingController(text: e?.perUserLimit.toString() ?? '1');
    _totalCap = TextEditingController(text: e?.totalCap.toString() ?? '0');
    _discountType = e?.discountType ?? 'PERCENT';
    _validFrom = e?.validFrom ?? DateTime.now();
    _validUntil =
        e?.validUntil ?? DateTime.now().add(const Duration(days: 30));
    _isActive = e?.isActive ?? true;
    _isPublic = e?.isPublic ?? false;
    _firstOrderOnly = e?.firstOrderOnly ?? false;
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _description.dispose();
    _discountValue.dispose();
    _maxDiscount.dispose();
    _minOrder.dispose();
    _perUserLimit.dispose();
    _totalCap.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _validFrom : _validUntil,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _validFrom = picked;
      } else {
        _validUntil = picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ds = context.read<MerchantCouponsRemoteDataSource>();
      final discountValue = double.tryParse(_discountValue.text.trim()) ?? 0;
      final maxDiscount = double.tryParse(_maxDiscount.text.trim());
      final minOrder = double.tryParse(_minOrder.text.trim()) ?? 0;
      final perUser = int.tryParse(_perUserLimit.text.trim()) ?? 1;
      final totalCap = int.tryParse(_totalCap.text.trim()) ?? 0;
      if (widget.existing == null) {
        await ds.create(
          code: _code.text.trim().toUpperCase(),
          title: _title.text.trim(),
          description: _description.text.trim(),
          discountType: _discountType,
          discountValue: discountValue,
          maxDiscount: maxDiscount,
          minOrderAmount: minOrder,
          validFrom: _validFrom,
          validUntil: _validUntil,
          perUserLimit: perUser,
          totalCap: totalCap,
          isPublic: _isPublic,
          firstOrderOnly: _firstOrderOnly,
          isActive: _isActive,
        );
      } else {
        await ds.update(
          widget.existing!.id,
          code: _code.text.trim().toUpperCase(),
          title: _title.text.trim(),
          description: _description.text.trim(),
          discountType: _discountType,
          discountValue: discountValue,
          maxDiscount: maxDiscount,
          minOrderAmount: minOrder,
          validFrom: _validFrom,
          validUntil: _validUntil,
          perUserLimit: perUser,
          totalCap: totalCap,
          isPublic: _isPublic,
          firstOrderOnly: _firstOrderOnly,
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.lg,
        right: AppSizes.lg,
        top: AppSizes.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSizes.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEdit ? l10n.couponsEditCoupon : l10n.couponsNewCoupon,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: _code,
              decoration: InputDecoration(
                labelText: l10n.couponsFieldCode,
                hintText: 'WELCOME10',
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_-]')),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: l10n.couponsFieldTitle,
                hintText: l10n.couponsFieldTitleHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _description,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.couponsFieldDescription,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _discountType,
                    decoration: InputDecoration(
                      labelText: l10n.couponsFieldType,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'PERCENT',
                        child: Text(l10n.couponsDiscountTypePercent),
                      ),
                      DropdownMenuItem(
                        value: 'FLAT',
                        child: Text(l10n.couponsDiscountTypeFlat),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _discountType = v ?? 'PERCENT'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: TextField(
                    controller: _discountValue,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _discountType == 'PERCENT'
                          ? l10n.couponsFieldPercentOff
                          : l10n.couponsFieldAmountOff,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_discountType == 'PERCENT') ...[
              const SizedBox(height: AppSizes.sm),
              TextField(
                controller: _maxDiscount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.couponsFieldMaxDiscount,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _minOrder,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.couponsFieldMinOrder,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: true),
                    icon: const Icon(AppIcons.event),
                    label: Text(
                        '${l10n.couponsDateFrom}  ${_date.format(_validFrom)}'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: false),
                    icon: const Icon(AppIcons.eventAvailable),
                    label: Text(
                        '${l10n.couponsDateUntil} ${_date.format(_validUntil)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _perUserLimit,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.couponsFieldPerUserLimit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: TextField(
                    controller: _totalCap,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.couponsFieldTotalCap,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            SwitchListTile(
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
              title: Text(l10n.couponsPublicTitle),
              subtitle: Text(l10n.couponsPublicSubtitle),
            ),
            SwitchListTile(
              value: _firstOrderOnly,
              onChanged: (v) => setState(() => _firstOrderOnly = v),
              title: Text(l10n.couponsFirstOrderTitle),
              subtitle: Text(l10n.couponsFirstOrderSubtitle),
            ),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: Text(l10n.couponsActiveTitle),
              subtitle: Text(l10n.couponsActiveSubtitle),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.sm),
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                color: AppColors.errorSoft,
                child: Text(_error!,
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? l10n.couponsSaving
                    : isEdit
                        ? l10n.couponsSaveChanges
                        : l10n.couponsCreateCoupon,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
