import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnboardingDraft {
  const OnboardingDraft({
    required this.step,
    required this.legalName,
    required this.customerFacing,
    required this.contact,
    required this.email,
    required this.phone,
    required this.businessType,
    required this.category,
    required this.pan,
    required this.gst,
    required this.street1,
    required this.street2,
    required this.city,
    required this.state,
    required this.postal,
    required this.beneficiary,
    required this.account,
    required this.ifsc,
    required this.savedAtMs,
  });

  static const int currentVersion = 1;

  static const Duration maxAge = Duration(days: 14);

  final int step;
  final String legalName;
  final String customerFacing;
  final String contact;
  final String email;
  final String phone;
  final String businessType;
  final String category;
  final String pan;
  final String gst;
  final String street1;
  final String street2;
  final String city;
  final String? state;
  final String postal;
  final String beneficiary;
  final String account;
  final String ifsc;
  final int savedAtMs;

  bool isExpiredAt(int nowMs) => nowMs - savedAtMs > maxAge.inMilliseconds;

  String get stepLabel => const ['Business', 'Identity', 'Address', 'Bank']
      [step.clamp(0, 3)];

  Map<String, dynamic> toJson() => {
        'v': currentVersion,
        'step': step,
        'legalName': legalName,
        'customerFacing': customerFacing,
        'contact': contact,
        'email': email,
        'phone': phone,
        'businessType': businessType,
        'category': category,
        'pan': pan,
        'gst': gst,
        'street1': street1,
        'street2': street2,
        'city': city,
        'state': state,
        'postal': postal,
        'beneficiary': beneficiary,
        'account': account,
        'ifsc': ifsc,
        'savedAtMs': savedAtMs,
      };

  static OnboardingDraft? fromJson(Map<String, dynamic> j) {
    if (j['v'] != currentVersion) return null;
    String s(Object? v) => (v as String?) ?? '';
    return OnboardingDraft(
      step: (j['step'] as num?)?.toInt() ?? 0,
      legalName: s(j['legalName']),
      customerFacing: s(j['customerFacing']),
      contact: s(j['contact']),
      email: s(j['email']),
      phone: s(j['phone']),
      businessType: s(j['businessType']).isEmpty ? 'proprietorship' : s(j['businessType']),
      category: s(j['category']).isEmpty ? 'ecommerce' : s(j['category']),
      pan: s(j['pan']),
      gst: s(j['gst']),
      street1: s(j['street1']),
      street2: s(j['street2']),
      city: s(j['city']),
      state: (j['state'] as String?)?.isEmpty ?? true ? null : j['state'] as String,
      postal: s(j['postal']),
      beneficiary: s(j['beneficiary']),
      account: s(j['account']),
      ifsc: s(j['ifsc']),
      savedAtMs: (j['savedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class OnboardingDraftStore {
  const OnboardingDraftStore([this._storage = _defaultStorage]);

  static const FlutterSecureStorage _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _key = 'payout_onboarding_draft_v1';

  final FlutterSecureStorage _storage;

  Future<OnboardingDraft?> read({int? nowMs}) async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return null;
      final draft = OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (draft == null) {
        await clear();
        return null;
      }
      if (draft.isExpiredAt(nowMs ?? DateTime.now().millisecondsSinceEpoch)) {
        await clear();
        return null;
      }
      return draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(OnboardingDraft draft) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(draft.toJson()));
    } catch (_) {
    }
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
