import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/admin/data/models/platform_bank_offer.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_bank_offers_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Bottom-sheet editor for one PlatformBankOffer. Returns `true` to
/// the caller iff the save succeeded so the list page can refresh.
///
/// The Bank + Card type dropdowns are pinned to the codes the
/// customer PDP knows how to render. Adding a new bank means
/// updating this list AND the `_bankByCode` table in
/// `pdp_offers_strip.dart` — keep them in lockstep.
class AdminBankOfferEditorSheet {
  static Future<bool?> show(
    BuildContext context, {
    AdminPlatformBankOffer? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => _Body(existing: existing),
    );
  }
}

// Bank short-code → human-friendly label. Order matters — drives
// the dropdown sort.
const Map<String, String> _kBanks = {
  'HDFC': 'HDFC Bank',
  'ICICI': 'ICICI Bank',
  'SBI': 'State Bank of India',
  'AXIS': 'Axis Bank',
  'KOTAK': 'Kotak Mahindra Bank',
  'AMEX': 'American Express',
  'YES': 'YES Bank',
  'HSBC': 'HSBC',
  'SC': 'Standard Chartered',
  'IDFC': 'IDFC First Bank',
  'BOB': 'Bank of Baroda',
  'RBL': 'RBL Bank',
};

const Map<String, String> _kCardTypes = {
  'ANY': 'Any',
  'CREDIT': 'Credit Cards',
  'DEBIT': 'Debit Cards',
  'CREDIT_DEBIT': 'Credit & Debit Cards',
  'NET_BANKING': 'Net Banking',
  'EMI': 'EMI',
};

class _Body extends StatefulWidget {
  const _Body({this.existing});
  final AdminPlatformBankOffer? existing;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final TextEditingController _discountValue;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _minOrder;
  late final TextEditingController _terms;

  String _bank = 'HDFC';
  String _cardType = 'ANY';
  String _discountType = 'PERCENT';
  late DateTime _validFrom;
  late DateTime _validUntil;
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  static final _date = DateFormat('d MMM y');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _discountValue = TextEditingController(
      text: e?.discountValue.toStringAsFixed(0) ?? '',
    );
    _maxDiscount = TextEditingController(
      text: e?.maxDiscount != null ? e!.maxDiscount!.toStringAsFixed(0) : '',
    );
    _minOrder = TextEditingController(
      text: e?.minOrderAmount.toStringAsFixed(0) ?? '0',
    );
    _terms = TextEditingController(text: e?.terms ?? '');
    _bank = (e?.bank.isNotEmpty ?? false) ? e!.bank : 'HDFC';
    _cardType = (e?.cardType.isNotEmpty ?? false) ? e!.cardType : 'ANY';
    _discountType = e?.discountType ?? 'PERCENT';
    _validFrom = e?.validFrom ?? DateTime.now();
    _validUntil = e?.validUntil ??
        DateTime.now().add(const Duration(days: 30));
    _isActive = e?.isActive ?? true;
    // Unknown legacy enum values fall back to the first option so
    // the dropdown doesn't assert.
    if (!_kBanks.containsKey(_bank)) _bank = 'HDFC';
    if (!_kCardTypes.containsKey(_cardType)) _cardType = 'ANY';
  }

  @override
  void dispose() {
    _discountValue.dispose();
    _maxDiscount.dispose();
    _minOrder.dispose();
    _terms.dispose();
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
      final body = <String, dynamic>{
        'bank': _bank,
        'cardType': _cardType,
        'discountType': _discountType,
        'discountValue': double.tryParse(_discountValue.text.trim()) ?? 0,
        'minOrderAmount': double.tryParse(_minOrder.text.trim()) ?? 0,
        'validFrom': _validFrom.toUtc().toIso8601String(),
        'validUntil': _validUntil.toUtc().toIso8601String(),
        'isActive': _isActive,
      };
      final maxD = double.tryParse(_maxDiscount.text.trim());
      if (maxD != null && maxD > 0) body['maxDiscount'] = maxD;
      final t = _terms.text.trim();
      if (t.isNotEmpty) body['terms'] = t;

      final provider = context.read<AdminBankOffersProvider>();
      if (widget.existing == null) {
        await provider.create(body);
      } else {
        await provider.update(widget.existing!.id, body);
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
    final isEdit = widget.existing != null;
    // Live-compose the same headline string the customer card will
    // render, so the admin sees what they're publishing.
    final discountStr =
        double.tryParse(_discountValue.text.trim())?.toStringAsFixed(0) ?? '0';
    final capStr = (_discountType == 'PERCENT' &&
            (double.tryParse(_maxDiscount.text.trim()) ?? 0) > 0)
        ? ' up to ₹$_maxDiscount'
            .replaceFirst(_maxDiscount.text, _maxDiscount.text.trim())
        : '';
    final cardLabel = _cardType == 'ANY' ? '' : ' ${_kCardTypes[_cardType]}';
    final preview = _discountType == 'PERCENT'
        ? '$discountStr% off$capStr on ${_kBanks[_bank]}$cardLabel'
        : '₹$discountStr off on ${_kBanks[_bank]}$cardLabel';

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
              isEdit ? 'Edit bank offer' : 'New bank offer',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSizes.md),
            DropdownButtonFormField<String>(
              initialValue: _bank,
              decoration: const InputDecoration(
                labelText: 'Bank',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in _kBanks.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _bank = v ?? _bank),
            ),
            const SizedBox(height: AppSizes.sm),
            DropdownButtonFormField<String>(
              initialValue: _cardType,
              decoration: const InputDecoration(
                labelText: 'Card type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in _kCardTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _cardType = v ?? _cardType),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _discountType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'PERCENT', child: Text('Percent off')),
                      DropdownMenuItem(
                          value: 'FLAT', child: Text('Flat ₹ off')),
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
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText:
                          _discountType == 'PERCENT' ? '% off' : '₹ off',
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Max discount (₹) — caps the % off',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _minOrder,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum order (₹) — eligibility filter',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            TextField(
              controller: _terms,
              maxLength: 280,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Terms (optional)',
                hintText:
                    'e.g. Not valid on no-cost EMI. Excludes Apple products.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: true),
                    icon: const Icon(Icons.event),
                    label: Text('From  ${_date.format(_validFrom)}'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(isFrom: false),
                    icon: const Icon(Icons.event_available),
                    label: Text('Until ${_date.format(_validUntil)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Active'),
              subtitle: const Text(
                'When off, the offer never decorates a PDP. Use this to '
                'park a draft or expire an offer early without deleting it.',
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: ShapeDecoration(
                color: AppColors.canvas,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PDP preview',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    preview,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.sm),
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                color: AppColors.errorSoft,
                child: Text(_error!,
                    style: const TextStyle(color: AppColors.error)),
              ),
            ],
            const SizedBox(height: AppSizes.md),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Saving…'
                    : isEdit
                        ? 'Save changes'
                        : 'Create offer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
