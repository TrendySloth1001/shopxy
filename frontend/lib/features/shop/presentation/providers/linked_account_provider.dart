import 'package:flutter/foundation.dart';
import 'package:shopxy/features/shop/data/datasources/linked_account_remote_data_source.dart';
import 'package:shopxy/features/shop/data/datasources/onboarding_draft_store.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class LinkedAccountProvider extends ChangeNotifier {
  LinkedAccountProvider(this._ds, [this._draftStore = const OnboardingDraftStore()]);

  final LinkedAccountRemoteDataSource _ds;
  final OnboardingDraftStore _draftStore;

  LinkedAccountStatus? _status;
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  OnboardingDraft? _draft;

  bool _promptDismissed = false;

  LinkedAccountStatus? get status => _status;
  bool get loaded => _loaded;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get promptDismissed => _promptDismissed;

  OnboardingDraft? get draft => _draft;

  bool get hasDraft => _draft != null && _status == null;

  bool get notStarted => _loaded && _status == null;

  bool get needsOnboarding =>
      _loaded && (_status == null || !_status!.payoutsEnabled);

  bool get shouldPrompt => needsOnboarding && !_promptDismissed;

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
    _draft = await _draftStore.read();
    if (_draft != null && _status != null) {
      _draft = null;
      await _draftStore.clear();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> saveDraft(OnboardingDraft draft) async {
    _draft = draft;
    notifyListeners();
    await _draftStore.write(draft);
  }

  Future<void> refreshDraft() async {
    _draft = await _draftStore.read();
    notifyListeners();
  }

  Future<void> clearDraft() async {
    if (_draft == null) return;
    _draft = null;
    notifyListeners();
    await _draftStore.clear();
  }

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

  void reset() {
    _status = null;
    _loaded = false;
    _loading = false;
    _error = null;
    _promptDismissed = false;
    _draft = null;
    notifyListeners();
    _draftStore.clear();
  }
}
