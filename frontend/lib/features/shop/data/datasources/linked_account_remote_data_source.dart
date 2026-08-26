import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';

class LinkedAccountStatus {
  const LinkedAccountStatus({
    required this.kycStatus,
    required this.payoutsEnabled,
    this.providerAccountId,
    this.email,
    this.contactName,
    this.businessType,
  });

  final String kycStatus;
  final bool payoutsEnabled;
  final String? providerAccountId;
  final String? email;
  final String? contactName;
  final String? businessType;

  factory LinkedAccountStatus.fromJson(Map<String, dynamic> json) {
    return LinkedAccountStatus(
      kycStatus: (json['kycStatus'] as String?) ?? 'CREATED',
      payoutsEnabled: (json['payoutsEnabled'] as bool?) ?? false,
      providerAccountId: json['providerAccountId'] as String?,
      email: json['email'] as String?,
      contactName: json['contactName'] as String?,
      businessType: json['businessType'] as String?,
    );
  }
}

class ConnectAccountDetails {
  const ConnectAccountDetails({
    required this.accountId,
    required this.kycStatus,
    required this.payoutsEnabled,
    this.email,
    this.legalBusinessName,
    this.contactName,
    this.businessType,
  });

  final String accountId;
  final String kycStatus;
  final bool payoutsEnabled;
  final String? email;
  final String? legalBusinessName;
  final String? contactName;
  final String? businessType;

  factory ConnectAccountDetails.fromJson(Map<String, dynamic> json) {
    return ConnectAccountDetails(
      accountId: json['accountId'] as String,
      kycStatus: (json['kycStatus'] as String?) ?? 'CREATED',
      payoutsEnabled: (json['payoutsEnabled'] as bool?) ?? false,
      email: json['email'] as String?,
      legalBusinessName: json['legalBusinessName'] as String?,
      contactName: json['contactName'] as String?,
      businessType: json['businessType'] as String?,
    );
  }
}

class LinkedAccountRemoteDataSource {
  const LinkedAccountRemoteDataSource(this._client);
  final ApiClient _client;

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

  Future<ConnectAccountDetails> verifyConnect(String accountId) async {
    final res = await _client.post('/linked-account/connect', body: {'accountId': accountId});
    if (res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not verify that account'));
    }
    return ConnectAccountDetails.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<LinkedAccountStatus> confirmConnect(String accountId) async {
    final res = await _client.post('/linked-account/connect/confirm', body: {'accountId': accountId});
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(_error(res.body, 'Could not link that account'));
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
