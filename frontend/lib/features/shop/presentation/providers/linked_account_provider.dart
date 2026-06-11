import 'package:flutter/foundation.dart';
import 'package:shopxy/features/shop/data/datasources/linked_account_remote_data_source.dart';
import 'package:shopxy/features/shop/data/datasources/onboarding_draft_store.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// App-wide state for the shop's Razorpay Route payout (linked) account.
///
/// Two surfaces read this:
///  - the "Payouts & settlement" tile in Shop operations (shows live status
///    instead of a static "Coming soon" chip), and
///  - the dashboard, which nudges the owner with a one-time bottom sheet until
///    payouts are set up.
///
/// `getStatus()` returns null when onboarding hasn't started (backend 404), so
/// [notStarted] and [needsOnboarding] both fall out of the same load.
class LinkedAccountProvider extends ChangeNotifier {
  LinkedAccountProvider(this._ds, [this._draftStore = const OnboardingDraftStore()]);

  final LinkedAccountRemoteDataSource _ds;
  final OnboardingDraftStore _draftStore;

  LinkedAccountStatus? _status;
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  /// Locally-saved, half-filled onboarding form (device-only, encrypted). Null
  /// when there's nothing to resume.
  OnboardingDraft? _draft;

  /// True once the owner dismisses the startup nudge — kept for the rest of
  /// the session so we don't re-prompt on every dashboard appearance. Reset on
  /// logout via [reset].
  bool _promptDismissed = false;

  LinkedAccountStatus? get status => _status;
  bool get loaded => _loaded;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get promptDismissed => _promptDismissed;

  /// The saved draft, if any (PII — do not log).
  OnboardingDraft? get draft => _draft;

  /// Whether there's a resumable draft and no account yet.
  bool get hasDraft => _draft != null && _status == null;

  /// No account row at all yet (never started onboarding).
  bool get notStarted => _loaded && _status == null;

  /// Payouts aren't live yet — either never started or KYC not through.
  bool get needsOnboarding =>
      _loaded && (_status == null || !_status!.payoutsEnabled);

  /// Whether the dashboard should surface the one-time setup nudge.
  bool get shouldPrompt => needsOnboarding && !_promptDismissed;

  /// Loads once per session unless [force]. Failures are swallowed into
  /// [error] — a payout-status hiccup must never block the dashboard.
  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loaded && !force) return;
    _loading = true;
    if (force) _error = null;
    notifyListeners();
    try {
      _status = await _ds.getStatus(refresh: force);
      _loaded = true;
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    }
    // Read the resumable draft alongside status (best-effort). An activated
    // account makes the draft moot, so drop it if one exists server-side.
    _draft = await _draftStore.read();
    if (_draft != null && _status != null) {
      _draft = null;
      await _draftStore.clear();
    }
    _loading = false;
    notifyListeners();
  }

  /// Persist the half-filled form (device-only, encrypted) and reflect it so the
  /// dashboard nudge + operations tile show "Continue / In progress".
  Future<void> saveDraft(OnboardingDraft draft) async {
    _draft = draft;
    notifyListeners();
    await _draftStore.write(draft);
  }

  /// Re-read just the draft from secure storage (no network). The wizard calls
  /// this on entry so resume works even if it was opened before [load] ran.
  Future<void> refreshDraft() async {
    _draft = await _draftStore.read();
    notifyListeners();
  }

  /// Drop the saved draft (on successful submit or explicit "Start over").
  Future<void> clearDraft() async {
    if (_draft == null) return;
    _draft = null;
    notifyListeners();
    await _draftStore.clear();
  }

  /// Replace the cached status after the owner submits onboarding (or a manual
  /// refresh) so dependent surfaces update without a round-trip.
  void setStatus(LinkedAccountStatus? status) {
    _status = status;
    _loaded = true;
    notifyListeners();
  }

  void dismissPrompt() {
    if (_promptDismissed) return;
    _promptDismissed = true;
    notifyListeners();
  }

  /// Cleared on logout so the next user starts fresh. CRITICAL: also wipes the
  /// on-device draft — it holds the previous user's PAN/bank and must not leak
  /// across a session change.
  void reset() {
    _status = null;
    _loaded = false;
    _loading = false;
    _error = null;
    _promptDismissed = false;
    _draft = null;
    notifyListeners();
    // Fire-and-forget secure wipe (reset is sync; the delete needn't be awaited).
    _draftStore.clear();
  }
}
