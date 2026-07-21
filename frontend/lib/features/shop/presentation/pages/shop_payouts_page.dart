import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/shop/data/datasources/linked_account_remote_data_source.dart';
import 'package:shopxy/features/shop/data/datasources/onboarding_draft_store.dart';
import 'package:shopxy/features/shop/presentation/pages/connect_linked_account_page.dart';
import 'package:shopxy/features/shop/presentation/providers/linked_account_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Payouts & settlement onboarding. Wires the shop to a Razorpay Route linked
/// account so the shop's slice of each marketplace order can settle to its bank.
///
/// Onboarding is a 4-step wizard — Business → Identity (PAN/GST) → Registered
/// address → Settlement bank — matching what Razorpay's `POST /v2/accounts`
/// needs for a submittable account (legal_info + profile + bank). KYC then runs
/// asynchronously at Razorpay; we poll status until payouts go live.
///
/// PAN/GST and bank details are sent straight to Razorpay and never stored.
/// Layout is editorial: a fixed progress header, a scrollable step body, and a
/// pinned footer — no cards.
class ShopPayoutsPage extends StatefulWidget {
  const ShopPayoutsPage({super.key});

  @override
  State<ShopPayoutsPage> createState() => _ShopPayoutsPageState();
}

class _ShopPayoutsPageState extends State<ShopPayoutsPage>
    with WidgetsBindingObserver {
  late final LinkedAccountRemoteDataSource _ds;
  // Cached in initState — safe to use in dispose (context.read isn't).
  late final LinkedAccountProvider _provider;

  // One form key per step so "Continue" only validates the visible fields.
  final _stepKeys = List.generate(4, (_) => GlobalKey<FormState>());

  // Business
  final _legalName = TextEditingController();
  final _customerFacing = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  String _businessType = 'proprietorship';
  String _category = 'ecommerce';
  // Identity
  final _pan = TextEditingController();
  final _gst = TextEditingController();
  // Address
  final _street1 = TextEditingController();
  final _street2 = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  String? _state;
  // Bank
  final _beneficiary = TextEditingController();
  final _account = TextEditingController();
  final _ifsc = TextEditingController();

  int _step = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  LinkedAccountStatus? _status;

  /// A resumable draft exists and the user hasn't yet chosen Resume/Discard.
  bool _resumeOffered = false;

  static const _steps = ['Business', 'Identity', 'Address', 'Bank'];

  @override
  void initState() {
    super.initState();
    // TODO SECURITY (SCRN-1): this screen renders/collects KYC PII (PAN/GST/
    // bank). Enable screenshot + recents-thumbnail protection here (Android
    // FLAG_SECURE / iOS app-switcher blur) and disable it in dispose(). No
    // cross-platform package is currently a dependency — needs a package
    // decision (e.g. screen_protector / no_screenshot) before wiring.
    _ds = LinkedAccountRemoteDataSource(context.read<ApiClient>());
    _provider = context.read<LinkedAccountProvider>();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    // Last-chance save in case the page is popped mid-edit. Runs unconditionally
    // (mounted is already false here) via the cached provider.
    _persist();
    WidgetsBinding.instance.removeObserver(this);
    for (final c in [
      _legalName, _customerFacing, _contact, _email, _phone,
      _pan, _gst, _street1, _street2, _city, _postal,
      _beneficiary, _account, _ifsc,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save when backgrounded — catches "filled a step then left the app"
    // without writing secure storage on every keystroke.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _autosave();
    }
  }

  Future<void> _init() async {
    await _load();
    if (!mounted || _status != null) return;
    // No account yet → see if there's a saved draft to resume.
    await _provider.refreshDraft();
    if (mounted && _provider.draft != null) {
      setState(() => _resumeOffered = true);
    }
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _ds.getStatus(refresh: refresh);
      if (mounted) {
        setState(() => _status = status);
        _provider.setStatus(status);
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Draft persistence ──────────────────────────────────────────────────────

  /// True once the user has typed anything worth saving — avoids persisting an
  /// empty draft that would wrongly flip the dashboard to "Continue".
  bool _hasAnyInput() =>
      _step > 0 ||
      [_legalName, _customerFacing, _contact, _email, _phone, _pan, _gst,
              _street1, _street2, _city, _postal, _beneficiary, _account, _ifsc]
          .any((c) => c.text.trim().isNotEmpty) ||
      _state != null;

  OnboardingDraft _snapshot() => OnboardingDraft(
        step: _step,
        legalName: _legalName.text,
        customerFacing: _customerFacing.text,
        contact: _contact.text,
        email: _email.text,
        phone: _phone.text,
        businessType: _businessType,
        category: _category,
        pan: _pan.text,
        gst: _gst.text,
        street1: _street1.text,
        street2: _street2.text,
        city: _city.text,
        state: _state,
        postal: _postal.text,
        beneficiary: _beneficiary.text,
        account: _account.text,
        ifsc: _ifsc.text,
        savedAtMs: DateTime.now().millisecondsSinceEpoch,
      );

  /// Persist the current form (best-effort) unless we've already submitted or
  /// there's nothing meaningful to save. No `mounted` check — also called from
  /// dispose(), where mounted is already false.
  void _persist() {
    if (_submitting || _status != null || !_hasAnyInput()) return;
    _provider.saveDraft(_snapshot());
  }

  /// Mounted-safe wrapper for the lifecycle/step-transition callbacks.
  void _autosave() {
    if (!mounted) return;
    _persist();
  }

  void _applyDraft(OnboardingDraft d) {
    _legalName.text = d.legalName;
    _customerFacing.text = d.customerFacing;
    _contact.text = d.contact;
    _email.text = d.email;
    _phone.text = d.phone;
    _pan.text = d.pan;
    _gst.text = d.gst;
    _street1.text = d.street1;
    _street2.text = d.street2;
    _city.text = d.city;
    _postal.text = d.postal;
    _beneficiary.text = d.beneficiary;
    _account.text = d.account;
    _ifsc.text = d.ifsc;
    setState(() {
      _businessType = d.businessType;
      _category = d.category;
      _state = d.state;
      _step = d.step.clamp(0, _steps.length - 1);
      _resumeOffered = false;
    });
  }

  void _onContinue() {
    if (!(_stepKeys[_step].currentState?.validate() ?? false)) return;
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      _autosave();
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final status = await _ds.startOnboarding(
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        legalBusinessName: _legalName.text.trim(),
        customerFacingBusinessName: _customerFacing.text.trim(),
        businessType: _businessType,
        contactName: _contact.text.trim(),
        category: _category,
        pan: _pan.text.trim().toUpperCase(),
        gst: _gst.text.trim().toUpperCase(),
        addressStreet1: _street1.text.trim(),
        addressStreet2: _street2.text.trim(),
        addressCity: _city.text.trim(),
        addressState: (_state ?? '').toUpperCase(),
        addressPostalCode: _postal.text.trim(),
        beneficiaryName: _beneficiary.text.trim(),
        bankAccountNumber: _account.text.trim(),
        bankIfsc: _ifsc.text.trim().toUpperCase(),
      );
      if (mounted) {
        setState(() => _status = status);
        // Onboarding done → reflect status, stop the nudge, and wipe the draft
        // (it holds PAN/bank and is no longer needed).
        _provider
          ..setStatus(status)
          ..dismissPrompt();
        await _provider.clearDraft();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).shopPayoutsSubmittedSnack)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Localized display title for a wizard step index.
  String _stepTitle(AppLocalizations l10n, int i) {
    switch (i) {
      case 0:
        return l10n.shopStepBusiness;
      case 1:
        return l10n.shopStepIdentity;
      case 2:
        return l10n.shopStepAddress;
      default:
        return l10n.shopStepBank;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.shopPayoutsTitle,
        actions: [
          TextButton(
            onPressed: () async {
              final linked = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const ConnectLinkedAccountPage()),
              );
              if (linked == true && mounted) await _load(refresh: true);
            },
            child: Text(l10n.shopConnectExisting),
          ),
        ],
      ),
      body: _loading
          ? const _PayoutsWizardSkeleton()
          : _status != null
              ? _statusView()
              : _wizard(),
    );
  }

  // Existing account → just show its KYC status (no wizard).
  Widget _statusView() {
    return ListView(
      padding: EdgeInsets.only(
          top: AppSizes.lg + FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge),
      children: [
        if (_error != null) _ErrorLine(message: _error!, onRetry: () => _load()),
        _StatusSection(status: _status, onRefresh: () => _load(refresh: true)),
      ],
    );
  }

  Widget _wizard() {
    final l10n = AppLocalizations.of(context);
    final isLast = _step == _steps.length - 1;
    final draft = _provider.draft;
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Column(
      children: [
        SizedBox(height: FloatingAppBar.contentTopInset(context)),
        if (_error != null)
          _ErrorLine(
            message: _error!,
            actionLabel: l10n.shopDismiss,
            onRetry: () => setState(() => _error = null),
          ),
        if (_resumeOffered && draft != null)
          _ResumeBanner(
            draft: draft,
            onResume: () => _applyDraft(draft),
            onDiscard: () {
              _provider.clearDraft();
              setState(() => _resumeOffered = false);
            },
          ),
        _StepProgress(step: _step, total: _steps.length, title: _stepTitle(l10n, _step)),
        Divider(height: 1, thickness: 1, color: AppColors.hairline),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.lg),
            child: Form(
              key: _stepKeys[_step],
              child: _stepBody(),
            ),
          ),
        ),
        _footer(isLast: isLast),
      ],
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _BusinessStep(
          legalName: _legalName,
          customerFacing: _customerFacing,
          contact: _contact,
          email: _email,
          phone: _phone,
          businessType: _businessType,
          category: _category,
          onBusinessType: (v) => setState(() => _businessType = v),
          onCategory: (v) => setState(() => _category = v),
          field: _field,
          emailValidator: _emailValidator,
        );
      case 1:
        return _IdentityStep(pan: _pan, gst: _gst, field: _field);
      case 2:
        return _AddressStep(
          street1: _street1,
          street2: _street2,
          city: _city,
          postal: _postal,
          state: _state,
          onState: (v) => setState(() => _state = v),
          field: _field,
        );
      default:
        return _BankStep(
          beneficiary: _beneficiary,
          account: _account,
          ifsc: _ifsc,
          field: _field,
        );
    }
  }

  Widget _footer({required bool isLast}) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md),
        child: Row(
          children: [
            if (_step > 0)
              TextButton(
                onPressed: _submitting
                    ? null
                    : () {
                        setState(() => _step--);
                        _autosave();
                      },
                child: Text(l10n.shopBack),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _submitting ? null : _onContinue,
              child: _submitting
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.onInverse)))
                  : Text(isLast ? l10n.shopSetUpPayouts : l10n.shopContinue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    String? helper,
    bool optional = false,
  }) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: validator ??
            (optional
                ? null
                : (v) => (v == null || v.trim().isEmpty) ? l10n.shopFieldRequired : null),
      ),
    );
  }

  String? _emailValidator(String? v) {
    final s = (v ?? '').trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
        ? null
        : AppLocalizations.of(context).shopInvalidEmail;
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

/// Mirrors the wizard's fixed chrome (progress header, divider, form fields,
/// footer) while the initial status fetch is in flight.
class _PayoutsWizardSkeleton extends StatelessWidget {
  const _PayoutsWizardSkeleton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: FloatingAppBar.contentTopInset(context)),
        // ── Progress header (4-step indicator + step label) ──────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    Expanded(
                      child: AppShimmerBox(
                        height: AppSizes.xs,
                        radius: AppSizes.radiusFull,
                      ),
                    ),
                    if (i < 3) const SizedBox(width: AppSizes.xs),
                  ],
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              const AppShimmerLine(widthFactor: 0.45, height: 12),
            ],
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppColors.hairline),
        // ── Form body — mirrors _BusinessStep's label + input structure ───────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step intro title + subtitle
                const AppShimmerLine(widthFactor: 0.55, height: 22),
                const SizedBox(height: AppSizes.xs),
                const AppShimmerLine(widthFactor: 0.85, height: 13),
                const SizedBox(height: AppSizes.lg),
                // Field 1 — label chip + input box
                const AppShimmerLine(widthFactor: 0.3, height: 11),
                const SizedBox(height: AppSizes.xs),
                AppShimmerBox(height: 48, radius: AppSizes.radiusSm),
                const SizedBox(height: AppSizes.md),
                // Field 2
                const AppShimmerLine(widthFactor: 0.4, height: 11),
                const SizedBox(height: AppSizes.xs),
                AppShimmerBox(height: 48, radius: AppSizes.radiusSm),
                const SizedBox(height: AppSizes.md),
                // Field 3
                const AppShimmerLine(widthFactor: 0.35, height: 11),
                const SizedBox(height: AppSizes.xs),
                AppShimmerBox(height: 48, radius: AppSizes.radiusSm),
                const SizedBox(height: AppSizes.md),
                // Field 4
                const AppShimmerLine(widthFactor: 0.25, height: 11),
                const SizedBox(height: AppSizes.xs),
                AppShimmerBox(height: 48, radius: AppSizes.radiusSm),
              ],
            ),
          ),
        ),
        // ── Footer — buttons visible but disabled ────────────────────────────
        SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md),
            child: Row(
              children: [
                const Spacer(),
                FilledButton(
                  onPressed: null,
                  child: Text(l10n.shopContinue),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

// ── Step bodies ──────────────────────────────────────────────────────────────

typedef _FieldBuilder = Widget Function(
  TextEditingController c,
  String label, {
  TextInputType? keyboard,
  List<TextInputFormatter>? formatters,
  String? Function(String?)? validator,
  String? helper,
  bool optional,
});

class _BusinessStep extends StatelessWidget {
  const _BusinessStep({
    required this.legalName,
    required this.customerFacing,
    required this.contact,
    required this.email,
    required this.phone,
    required this.businessType,
    required this.category,
    required this.onBusinessType,
    required this.onCategory,
    required this.field,
    required this.emailValidator,
  });

  final TextEditingController legalName, customerFacing, contact, email, phone;
  final String businessType, category;
  final ValueChanged<String> onBusinessType, onCategory;
  final _FieldBuilder field;
  final String? Function(String?) emailValidator;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepIntro(
          title: l10n.shopBusinessStepTitle,
          subtitle: l10n.shopBusinessStepSubtitle,
        ),
        field(legalName, l10n.shopLegalBusinessName),
        field(customerFacing, l10n.shopDisplayName,
            helper: l10n.shopDisplayNameHelper,
            optional: true),
        field(contact, l10n.shopContactPersonName),
        field(email, l10n.shopEmail,
            keyboard: TextInputType.emailAddress, validator: emailValidator),
        field(phone, l10n.shopPhone,
            keyboard: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
            validator: (v) => (v == null || v.trim().length < 10) ? l10n.shopEnter10DigitNumber : null),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.md),
          child: DropdownButtonFormField<String>(
            initialValue: businessType,
            decoration: InputDecoration(labelText: l10n.shopBusinessType),
            items: [
              DropdownMenuItem(value: 'proprietorship', child: Text(l10n.shopBusinessTypeProprietorship)),
              DropdownMenuItem(value: 'partnership', child: Text(l10n.shopBusinessTypePartnership)),
              DropdownMenuItem(value: 'private_limited', child: Text(l10n.shopBusinessTypePrivateLimited)),
              DropdownMenuItem(value: 'public_limited', child: Text(l10n.shopBusinessTypePublicLimited)),
              DropdownMenuItem(value: 'llp', child: Text(l10n.shopBusinessTypeLlp)),
              DropdownMenuItem(value: 'individual', child: Text(l10n.shopBusinessTypeIndividual)),
              DropdownMenuItem(value: 'trust', child: Text(l10n.shopBusinessTypeTrust)),
              DropdownMenuItem(value: 'society', child: Text(l10n.shopBusinessTypeSociety)),
              DropdownMenuItem(value: 'ngo', child: Text(l10n.shopBusinessTypeNgo)),
            ],
            onChanged: (v) => onBusinessType(v ?? businessType),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: InputDecoration(labelText: l10n.shopBusinessCategory),
          items: [
            DropdownMenuItem(value: 'ecommerce', child: Text(l10n.shopCategoryEcommerce)),
            DropdownMenuItem(value: 'food', child: Text(l10n.shopCategoryFood)),
            DropdownMenuItem(value: 'services', child: Text(l10n.shopCategoryServices)),
            DropdownMenuItem(value: 'healthcare', child: Text(l10n.shopCategoryHealthcare)),
            DropdownMenuItem(value: 'education', child: Text(l10n.shopCategoryEducation)),
            DropdownMenuItem(value: 'others', child: Text(l10n.shopCategoryOthers)),
          ],
          onChanged: (v) => onCategory(v ?? category),
        ),
      ],
    );
  }
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({required this.pan, required this.gst, required this.field});
  final TextEditingController pan, gst;
  final _FieldBuilder field;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepIntro(
          title: l10n.shopIdentityStepTitle,
          subtitle: l10n.shopIdentityStepSubtitle,
        ),
        field(
          pan,
          'PAN',
          helper: l10n.shopPanHelper,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(10),
            _UpperCaseFormatter(),
          ],
          validator: (v) {
            final s = (v ?? '').trim().toUpperCase();
            return RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(s) ? null : l10n.shopInvalidPan;
          },
        ),
        field(
          gst,
          l10n.shopGstinOptional,
          helper: l10n.shopGstinHelper,
          optional: true,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(15),
            _UpperCaseFormatter(),
          ],
          validator: (v) {
            final s = (v ?? '').trim().toUpperCase();
            if (s.isEmpty) return null; // optional
            return RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$').hasMatch(s)
                ? null
                : l10n.shopInvalidGstin;
          },
        ),
      ],
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({
    required this.street1,
    required this.street2,
    required this.city,
    required this.postal,
    required this.state,
    required this.onState,
    required this.field,
  });
  final TextEditingController street1, street2, city, postal;
  final String? state;
  final ValueChanged<String?> onState;
  final _FieldBuilder field;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepIntro(
          title: l10n.shopAddressStepTitle,
          subtitle: l10n.shopAddressStepSubtitle,
        ),
        field(street1, l10n.shopAddressLine1),
        field(street2, l10n.shopAddressLine2, optional: true),
        field(city, l10n.shopCity),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.md),
          child: DropdownButtonFormField<String>(
            initialValue: state,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.shopState),
            items: _indianStates
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            validator: (v) => (v == null || v.isEmpty) ? l10n.shopSelectState : null,
            onChanged: onState,
          ),
        ),
        field(
          postal,
          l10n.shopPinCode,
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : l10n.shopEnter6DigitPin,
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSizes.xs),
          child: Text(l10n.shopCountryIndia,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted)),
        ),
      ],
    );
  }
}

class _BankStep extends StatelessWidget {
  const _BankStep({
    required this.beneficiary,
    required this.account,
    required this.ifsc,
    required this.field,
  });
  final TextEditingController beneficiary, account, ifsc;
  final _FieldBuilder field;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepIntro(
          title: l10n.shopBankStepTitle,
          subtitle: l10n.shopBankStepSubtitle,
        ),
        field(beneficiary, l10n.shopAccountHolderName),
        field(
          account,
          l10n.shopBankAccountNumber,
          keyboard: TextInputType.number,
          formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(20)],
          validator: (v) => (v == null || v.trim().length < 6) ? l10n.shopEnterValidAccountNumber : null,
        ),
        field(
          ifsc,
          'IFSC',
          formatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(11),
            _UpperCaseFormatter(),
          ],
          validator: (v) {
            final s = (v ?? '').trim().toUpperCase();
            return RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(s) ? null : l10n.shopInvalidIfsc;
          },
        ),
      ],
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.total, required this.title});
  final int step;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                Expanded(
                  child: Container(
                    height: AppSizes.xs,
                    decoration: BoxDecoration(
                      color: i <= step ? AppColors.brand : AppColors.hairline,
                      borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
                    ),
                  ),
                ),
                if (i < total - 1) const SizedBox(width: AppSizes.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            l10n.shopStepProgress(step + 1, total, title),
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// "You left off here — Resume / Start over" prompt shown on wizard entry when
/// a saved draft exists. Asks before restoring, per the resume UX.
class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.draft, required this.onResume, required this.onDiscard});
  final OnboardingDraft draft;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      color: AppColors.infoSoft,
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.historyRounded, color: AppColors.info, size: AppSizes.iconMd),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  l10n.shopResumeTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: AppSizes.xl),
            child: Text(
              l10n.shopResumeDraftUpTo(draft.stepLabel),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.info),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onDiscard, child: Text(l10n.shopStartOver)),
              const SizedBox(width: AppSizes.xs),
              FilledButton(
                onPressed: onResume,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg, vertical: AppSizes.sm),
                ),
                child: Text(l10n.shopResume),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({required this.status, required this.onRefresh});
  final LinkedAccountStatus? status;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final activated = status!.payoutsEnabled;
    final (label, color, icon) = activated
        ? (l10n.shopStatusActive, AppColors.success, AppIcons.verifiedRounded)
        : switch (status!.kycStatus) {
            'NEEDS_CLARIFICATION' => (
                l10n.shopStatusNeedsClarification,
                AppColors.error,
                AppIcons.errorOutline,
              ),
            'SUSPENDED' => (l10n.shopStatusSuspended, AppColors.error, AppIcons.block),
            'UNDER_REVIEW' => (l10n.shopStatusUnderReview, AppColors.info, AppIcons.hourglassTopRounded),
            // 'created' (and anything else) = not yet submitted/activated for Route.
            _ => (l10n.shopStatusNotActivated, AppColors.warning, AppIcons.pendingOutlined),
          };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: AppSizes.iconMd),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            activated
                ? l10n.shopStatusActivatedDesc
                : l10n.shopStatusNotEnabledDesc(status!.kycStatus.toLowerCase()),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.lg),
          _DetailRow(label: l10n.shopDetailAccountId, value: status!.providerAccountId ?? '—'),
          _DetailRow(label: l10n.shopDetailName, value: status!.contactName ?? '—'),
          _DetailRow(label: l10n.shopDetailEmail, value: status!.email ?? '—'),
          if (status!.businessType != null)
            _DetailRow(label: l10n.shopDetailBusinessType, value: status!.businessType!),
          _DetailRow(label: l10n.shopDetailKycStatus, value: status!.kycStatus),
          _DetailRow(label: l10n.shopDetailPayouts, value: activated ? l10n.shopEnabled : l10n.shopNotEnabledYet),
          const SizedBox(height: AppSizes.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRefresh,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(AppIcons.refresh, size: 18),
              label: Text(l10n.shopRefreshFromRazorpay),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
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
            width: 110,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle)),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.black)),
          ),
        ],
      ),
    );
  }
}

/// Flat error line (icon + colored text + retry), no filled banner.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.message, required this.onRetry, this.actionLabel});
  final String message;
  final VoidCallback onRetry;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.errorOutline, color: AppColors.error, size: AppSizes.iconMd),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(actionLabel ?? l10n.shopRetry),
          ),
        ],
      ),
    );
  }
}

/// Force-uppercases input (PAN/GST/IFSC) as the user types so the on-screen
/// value matches what we submit.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

const _indianStates = <String>[
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir',
  'Ladakh', 'Lakshadweep', 'Puducherry',
];
