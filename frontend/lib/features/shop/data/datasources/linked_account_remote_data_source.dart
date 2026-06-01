import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';

/// The shop's Razorpay Route payout (linked) account status, as the backend
/// `/linked-account` endpoints report it. Bank details are NEVER returned here
/// (they live only at Razorpay) — this is just the KYC lifecycle.
class LinkedAccountStatus {
  const LinkedAccountStatus({
    required this.kycStatus,
    required this.payoutsEnabled,
    this.providerAccountId,
  });

  /// CREATED | UNDER_REVIEW | NEEDS_CLARIFICATION | ACTIVATED | SUSPENDED |
  /// FUNDS_HELD | CREATING.
  final String kycStatus;
  final bool payoutsEnabled;
  final String? providerAccountId;

  factory LinkedAccountStatus.fromJson(Map<String, dynamic> json) {
    return LinkedAccountStatus(
      kycStatus: (json['kycStatus'] as String?) ?? 'CREATED',
      payoutsEnabled: (json['payoutsEnabled'] as bool?) ?? false,
      providerAccountId: json['providerAccountId'] as String?,
    );
  }
}

class LinkedAccountRemoteDataSource {
  const LinkedAccountRemoteDataSource(this._client);
  final ApiClient _client;

  /// GET /linked-account → null when onboarding hasn't started (404).
  Future<LinkedAccountStatus?> getStatus({bool refresh = false}) async {
    final res = await _client.get(
      '/linked-account',
      queryParameters: refresh ? const {'refresh': '1'} : null,
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception(_error(res.body, 'Failed to load payout status'));
    }
    return LinkedAccountStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// POST /linked-account → start KYC onboarding. PAN/GST and bank details flow
  /// straight to Razorpay; the app never persists them. Optional fields are
  /// omitted from the body when empty so backend validation doesn't reject blanks.
  Future<LinkedAccountStatus> startOnboarding({
    required String email,
    required String phone,
    required String legalBusinessName,
    String? customerFacingBusinessName,
    required String businessType,
    required String contactName,
    required String category,
    String? subcategory,
    required String pan,
    String? gst,
    required String addressStreet1,
    String? addressStreet2,
    required String addressCity,
    required String addressState,
    required String addressPostalCode,
    String addressCountry = 'IN',
    required String beneficiaryName,
    required String bankAccountNumber,
    required String bankIfsc,
  }) async {
    final registered = <String, dynamic>{
      'street1': addressStreet1,
      'city': addressCity,
      'state': addressState,
      'postalCode': addressPostalCode,
      'country': addressCountry,
      if (addressStreet2 != null && addressStreet2.isNotEmpty) 'street2': addressStreet2,
    };
    final res = await _client.post('/linked-account', body: {
      'email': email,
      'phone': phone,
      'legalBusinessName': legalBusinessName,
      if (customerFacingBusinessName != null && customerFacingBusinessName.isNotEmpty)
        'customerFacingBusinessName': customerFacingBusinessName,
      'businessType': businessType,
      'contactName': contactName,
      'category': category,
      if (subcategory != null && subcategory.isNotEmpty) 'subcategory': subcategory,
      'pan': pan,
      if (gst != null && gst.isNotEmpty) 'gst': gst,
      'registeredAddress': registered,
      'beneficiaryName': beneficiaryName,
      'bankAccountNumber': bankAccountNumber,
      'bankIfsc': bankIfsc,
    });
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(_error(res.body, 'Failed to start onboarding'));
    }
    return LinkedAccountStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  String _error(String body, String fallback) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return (decoded['error'] ?? decoded['message'])?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
