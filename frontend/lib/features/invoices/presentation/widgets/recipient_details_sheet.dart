import 'package:flutter/material.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/invoices/domain/entities/recipient_details.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/indian.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';

enum RecipientRequirement {
  b2b,

  highValue,
}

sealed class RecipientOutcome {
  const RecipientOutcome();
}

class RecipientFilled extends RecipientOutcome {
  const RecipientFilled(this.details, {required this.saveToParty});
  final RecipientDetails details;
  final bool saveToParty;
}

class RecipientSkipped extends RecipientOutcome {
  const RecipientSkipped();
}

Future<RecipientOutcome?> showRecipientDetailsSheet(
  BuildContext context, {
  required RecipientRequirement requirement,
  required bool nameMissing,
  required bool addressMissing,
  required bool canSaveToParty,
  String? initialCity,
  String? initialStateCode,
  String? initialPinCode,
}) {
  return showModalBottomSheet<RecipientOutcome>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _RecipientDetailsSheet(
      requirement: requirement,
      nameMissing: nameMissing,
      addressMissing: addressMissing,
      canSaveToParty: canSaveToParty,
      initialCity: initialCity,
      initialStateCode: initialStateCode,
      initialPinCode: initialPinCode,
    ),
  );
}

class _RecipientDetailsSheet extends StatefulWidget {
  const _RecipientDetailsSheet({
    required this.requirement,
    required this.nameMissing,
    required this.addressMissing,
    required this.canSaveToParty,
    this.initialCity,
    this.initialStateCode,
    this.initialPinCode,
  });

  final RecipientRequirement requirement;
  final bool nameMissing;
  final bool addressMissing;
  final bool canSaveToParty;
  final String? initialCity;
  final String? initialStateCode;
  final String? initialPinCode;

  @override
  State<_RecipientDetailsSheet> createState() => _RecipientDetailsSheetState();
}

class _RecipientDetailsSheetState extends State<_RecipientDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _pin;
  String? _stateCode;
  late bool _saveToParty = widget.canSaveToParty;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController();
    _city = TextEditingController(text: widget.initialCity ?? '');
    _pin = TextEditingController(text: widget.initialPinCode ?? '');
    _stateCode = widget.initialStateCode;
  }

  @override
  void dispose() {
    _address.dispose();
    _city.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      RecipientFilled(
        RecipientDetails(
          address: _address.text,
          city: _city.text,
          state: IndianStates.stateNameFromCode(_stateCode),
          stateCode: _stateCode,
          pinCode: _pin.text,
        ),
        saveToParty: _saveToParty,
      ),
    );
  }

  Future<void> _skip() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.invoicesRecipientSkipWarnTitle,
      message: l10n.invoicesRecipientSkipWarnBody,
      confirmLabel: l10n.invoicesRecipientSkipConfirm,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    Navigator.pop(context, const RecipientSkipped());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final missing = [
      if (widget.nameMissing) l10n.invoicesRecipientMissingName,
      if (widget.addressMissing) l10n.invoicesRecipientMissingAddress,
    ].join(' · ');

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.md),
            Container(
              width: AppSizes.handleWidth,
              height: AppSizes.handleHeight,
              decoration: ShapeDecoration(
                color: AppColors.hairline,
                shape: AppShapes.squircle(AppSizes.radiusFull),
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  children: [
                    Text(
                      l10n.invoicesRecipientTitle,
                      style: theme.textTheme.titleMedium?.bold,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      switch (widget.requirement) {
                        RecipientRequirement.b2b =>
                          l10n.invoicesRecipientWhyB2b,
                        RecipientRequirement.highValue =>
                          l10n.invoicesRecipientWhyHighValue,
                      },
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: ShapeDecoration(
                        color: AppColors.tileBg(AppColors.warningSoft),
                        shape: AppShapes.squircle(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          AppIcon(
                            AppIcons.warningAmberRounded,
                            color: AppColors.warning,
                            size: AppSizes.iconMd,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              '${l10n.invoicesRecipientMissingIntro} $missing',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.xl),
                    TextFormField(
                      controller: _address,
                      decoration: InputDecoration(
                        labelText: l10n.invoicesRecipientAddress,
                      ),
                      textCapitalization: TextCapitalization.words,
                      minLines: 2,
                      maxLines: 3,
                      autofocus: true,
                      validator: (_) => _anyFilled ? null : '',
                    ),
                    const SizedBox(height: AppSizes.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _city,
                            decoration: InputDecoration(
                              labelText: l10n.invoicesRecipientCity,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: TextFormField(
                            controller: _pin,
                            decoration: InputDecoration(
                              labelText: l10n.invoicesRecipientPin,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return null;
                              return IndianValidators.pincodeRegex.hasMatch(t)
                                  ? null
                                  : '';
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    DropdownButtonFormField<String>(
                      initialValue: _stateCode,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.invoicesRecipientState,
                      ),
                      items: [
                        for (final s in IndianStates.all)
                          DropdownMenuItem<String>(
                            value: s.code,
                            child: Text('${s.code} — ${s.name}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _stateCode = v),
                    ),
                    if (widget.canSaveToParty) ...[
                      const SizedBox(height: AppSizes.md),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _saveToParty,
                        onChanged: (v) => setState(() => _saveToParty = v),
                        title: Text(
                          l10n.invoicesRecipientSaveToParty,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(
                          l10n.invoicesRecipientSaveToPartyHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  AppButton.ghost(
                    label: l10n.invoicesRecipientSkip,
                    onPressed: _skip,
                  ),
                  const Spacer(),
                  AppButton.primary(
                    label: l10n.invoicesRecipientFillAndContinue,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _anyFilled =>
      _address.text.trim().isNotEmpty ||
      _city.text.trim().isNotEmpty ||
      _pin.text.trim().isNotEmpty ||
      _stateCode != null;
}
