import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/invoice_numbering/presentation/pages/invoice_numbering_page.dart';
import 'package:shopxy/features/pdf_templates/presentation/pages/pdf_templates_page.dart';
import 'package:shopxy/features/profile/presentation/pages/edit_profile_page.dart'
    show ProfileField;
import 'package:shopxy/features/profile/presentation/widgets/gst_effective_date_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/indian.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class InvoiceSettingsPage extends StatefulWidget {
  const InvoiceSettingsPage({
    super.key,
    this.focusField,
    this.focusGstEffectiveDate = false,
  });

  final ProfileField? focusField;

  final bool focusGstEffectiveDate;

  @override
  State<InvoiceSettingsPage> createState() => _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends State<InvoiceSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopGstin;
  late final TextEditingController _shopPan;
  late final TextEditingController _upiVpa;
  DateTime? _gstEffectiveFrom;
  String? _gstEffectiveFromError;
  final _gstEffectiveFromKey = GlobalKey();
  bool _busy = false;

  bool _editingGstin = false;
  bool _editingPan = false;

  late final Map<ProfileField, FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _shopGstin = TextEditingController(text: user?.shopGstin ?? '');
    _shopPan = TextEditingController(text: user?.shopPan ?? '');
    _upiVpa = TextEditingController(text: user?.upiVpa ?? '');
    _editingGstin = (user?.shopGstin ?? '').trim().isEmpty;
    _editingPan = (user?.shopPan ?? '').trim().isEmpty;
    final storedEffectiveFrom = user?.gstEffectiveFrom;
    _gstEffectiveFrom = storedEffectiveFrom != null
        ? DateTime.tryParse(storedEffectiveFrom)
        : null;

    _focusNodes = {
      for (final f in const [
        ProfileField.shopGstin,
        ProfileField.shopPan,
        ProfileField.upiVpa,
      ])
        f: FocusNode(),
    };
    final target = widget.focusField;
    if (target != null && _focusNodes.containsKey(target)) {
      if (target == ProfileField.shopGstin) _editingGstin = true;
      if (target == ProfileField.shopPan) _editingPan = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[target]!.requestFocus();
      });
    } else if (widget.focusGstEffectiveDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _scrollToGstEffectiveDate();
        await _pickGstEffectiveFrom();
      });
    }
  }

  @override
  void dispose() {
    _shopGstin.dispose();
    _shopPan.dispose();
    _upiVpa.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _pickGstEffectiveFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _gstEffectiveFrom ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) {
      setState(() {
        _gstEffectiveFrom = picked;
        _gstEffectiveFromError = null;
      });
    }
  }

  void _unlockGstin() {
    setState(() => _editingGstin = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[ProfileField.shopGstin]!.requestFocus();
    });
  }

  void _unlockPan() {
    setState(() => _editingPan = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[ProfileField.shopPan]!.requestFocus();
    });
  }

  void _scrollToGstEffectiveDate() {
    final ctx = _gstEffectiveFromKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.2,
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    String? diff(String current, String? stored) {
      final next = current.trim();
      final prev = stored ?? '';
      if (next == prev) return null;
      return next;
    }

    final shopGstinArg = diff(_shopGstin.text.toUpperCase(), user?.shopGstin);
    final shopPanArg = diff(_shopPan.text.toUpperCase(), user?.shopPan);
    final upiArg = diff(_upiVpa.text, user?.upiVpa);

    final isNewGstinRegistration =
        shopGstinArg != null && shopGstinArg.isNotEmpty;
    if (isNewGstinRegistration && _gstEffectiveFrom == null) {
      final declared = await showGstEffectiveDateSheet(context);
      if (!mounted) return;
      if (declared == null) {
        _scrollToGstEffectiveDate();
        return;
      }
      setState(() {
        _gstEffectiveFrom = declared;
        _gstEffectiveFromError = null;
      });
    }

    final gstEffectiveFromText = _gstEffectiveFrom != null
        ? DateFormat('yyyy-MM-dd').format(_gstEffectiveFrom!)
        : '';
    final gstEffectiveFromArg = diff(
      gstEffectiveFromText,
      user?.gstEffectiveFrom,
    );

    final unchanged =
        shopGstinArg == null &&
        shopPanArg == null &&
        upiArg == null &&
        gstEffectiveFromArg == null;
    if (unchanged) {
      Navigator.pop(context);
      return;
    }

    final l10n = AppLocalizations.of(context);
    String shown(String? arg) =>
        (arg == null || arg.isEmpty) ? l10n.profileNotAdded : arg;
    final rows = <(String, String)>[
      if (shopGstinArg != null) (l10n.profileGstin, shown(shopGstinArg)),
      if (gstEffectiveFromArg != null)
        (
          l10n.profileGstEffectiveFrom,
          gstEffectiveFromArg.isEmpty
              ? l10n.profileNotAdded
              : DateFormat('d MMM y').format(DateTime.parse(gstEffectiveFromArg)),
        ),
      if (shopPanArg != null) (l10n.profilePan, shown(shopPanArg)),
      if (upiArg != null) (l10n.profileUpiId, shown(upiArg)),
    ];

    final confirmed = await _showPreviewSheet(context, rows);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await auth.updateProfile(
        shopGstin: shopGstinArg,
        gstEffectiveFrom: gstEffectiveFromArg,
        shopPan: shopPanArg,
        upiVpa: upiArg,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileProfileUpdated)),
      );
      context.findAncestorStateOfType<AppShellState>()?.selectDestination(
        'invoices',
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<bool?> _showPreviewSheet(
    BuildContext context,
    List<(String, String)> rows,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
      ),
      builder: (_) => _InvoiceSettingsPreviewSheet(rows: rows),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.profileInvoiceSettingsTitle),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.lg + FloatingAppBar.contentTopInset(context),
            AppSizes.lg,
            AppSizes.lg,
          ),
          children: [
            Text(
              l10n.profileInvoiceSettingsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Material(
              color: AppColors.surface,
              shape: AppShapes.squircle(
                AppSizes.radiusMd,
                side: BorderSide(color: AppColors.hairline),
              ),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvoiceNumberingPage()),
                ),
                customBorder: AppShapes.squircle(AppSizes.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: ShapeDecoration(
                          color: AppColors.brandSoft,
                          shape: AppShapes.squircle(10),
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(
                          AppIcons.tuneRounded,
                          size: 22,
                          color: AppColors.brandStrong,
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.numberingEntryTitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSizes.xxs),
                            Text(
                              l10n.numberingEntrySubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(
                        AppIcons.chevronRightRounded,
                        size: 20,
                        color: AppColors.subtle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Material(
              color: AppColors.surface,
              shape: AppShapes.squircle(
                AppSizes.radiusMd,
                side: BorderSide(color: AppColors.hairline),
              ),
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PdfTemplatesPage()),
                ),
                customBorder: AppShapes.squircle(AppSizes.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: ShapeDecoration(
                          color: AppColors.brandSoft,
                          shape: AppShapes.squircle(10),
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(
                          AppIcons.gridViewRounded,
                          size: 22,
                          color: AppColors.brandStrong,
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.pdfTemplatesEntryTitle,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: AppColors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSizes.xxs),
                            Text(
                              l10n.pdfTemplatesEntrySubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppIcon(
                        AppIcons.chevronRightRounded,
                        size: 20,
                        color: AppColors.subtle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            _LockableField(
              editing: _editingGstin,
              controller: _shopGstin,
              focusNode: _focusNodes[ProfileField.shopGstin],
              label: l10n.profileGstin,
              textCapitalization: TextCapitalization.characters,
              validator: IndianValidators.gstin,
              onUnlock: _unlockGstin,
            ),
            const SizedBox(height: AppSizes.md),
            _LockableField(
              editing: _editingPan,
              controller: _shopPan,
              focusNode: _focusNodes[ProfileField.shopPan],
              label: l10n.profilePan,
              textCapitalization: TextCapitalization.characters,
              validator: IndianValidators.pan,
              onUnlock: _unlockPan,
            ),
            const SizedBox(height: AppSizes.md),
            InkWell(
              key: _gstEffectiveFromKey,
              onTap: _pickGstEffectiveFrom,
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.profileGstEffectiveFrom,
                  helperText: l10n.profileGstEffectiveFromHelper,
                  helperMaxLines: 3,
                  errorText: _gstEffectiveFromError,
                  suffixIcon: const AppIcon(AppIcons.calendarTodayOutlined),
                ),
                child: Text(
                  _gstEffectiveFrom != null
                      ? DateFormat('d MMM y').format(_gstEffectiveFrom!)
                      : l10n.profileSelectPlaceholder,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _upiVpa,
              focusNode: _focusNodes[ProfileField.upiVpa],
              decoration: InputDecoration(
                labelText: l10n.profileUpiId,
                hintText: 'shop@upi',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: IndianValidators.upiVpa,
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseSurface,
                foregroundColor: AppColors.onInverse,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              child: _busy
                  ? SizedBox(
                      height: AppSizes.xl,
                      width: AppSizes.xl,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onInverse,
                      ),
                    )
                  : Text(l10n.profileSave),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockableField extends StatelessWidget {
  const _LockableField({
    required this.editing,
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.validator,
    required this.onUnlock,
    this.textCapitalization = TextCapitalization.none,
  });

  final bool editing;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? Function(String?) validator;
  final VoidCallback onUnlock;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return TextFormField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(labelText: label),
        textCapitalization: textCapitalization,
        validator: validator,
      );
    }
    return InkWell(
      onTap: onUnlock,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const AppIcon(AppIcons.editOutlined),
        ),
        child: Text(controller.text),
      ),
    );
  }
}

class _InvoiceSettingsPreviewSheet extends StatelessWidget {
  const _InvoiceSettingsPreviewSheet({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: AppSizes.handleHeight,
                decoration: ShapeDecoration(
                  color: AppColors.hairline,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              l10n.profileInvoiceSettingsPreviewTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              l10n.profileInvoiceSettingsPreviewBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Container(
              decoration: ShapeDecoration(
                color: AppColors.canvas,
                shape: AppShapes.squircle(
                  AppSizes.radiusMd,
                  side: BorderSide(color: AppColors.hairline),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: AppSizes.lg,
                        endIndent: AppSizes.lg,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.lg,
                        vertical: AppSizes.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              rows[i].$1,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Text(
                            rows[i].$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseSurface,
                foregroundColor: AppColors.onInverse,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.profileSave),
            ),
            const SizedBox(height: AppSizes.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.profileCancel),
            ),
          ],
        ),
      ),
    );
  }
}
