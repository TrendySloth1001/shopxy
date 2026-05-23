import 'package:shopxy/features/parties/domain/entities/party.dart';

class PartyDto {
  static Party fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return Party(
      id: json['id'] as int,
      name: json['name'] as String,
      contactName: json['contactName'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      stateCode: json['stateCode'] as String?,
      pinCode: json['pinCode'] as String?,
      panNumber: json['panNumber'] as String?,
      gstin: json['gstin'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      challanCount: count?['challans'] as int? ?? 0,
      invoiceCount: count?['invoices'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> toCreateJson({
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? stateCode,
    String? pinCode,
    String? panNumber,
    String? gstin,
  }) {
    String? clean(String? v) {
      if (v == null) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final data = <String, dynamic>{'name': name};
    void put(String key, String? value) {
      final v = clean(value);
      if (v != null) data[key] = v;
    }

    put('contactName', contactName);
    put('phone', phone);
    put('email', email);
    put('address', address);
    put('city', city);
    put('state', state);
    put('stateCode', stateCode);
    put('pinCode', pinCode);
    put('panNumber', panNumber);
    put('gstin', gstin);
    return data;
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? stateCode,
    String? pinCode,
    String? panNumber,
    String? gstin,
    bool? isActive,
  }) {
    /// Distinguishes "field unchanged" (caller passes null) from
    /// "field cleared by user" (caller passes empty string, which we
    /// serialise as JSON null).
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    void put(String key, String? value) {
      if (value == null) return;
      data[key] = value.isEmpty ? null : value;
    }

    put('contactName', contactName);
    put('phone', phone);
    put('email', email);
    put('address', address);
    put('city', city);
    put('state', state);
    put('stateCode', stateCode);
    put('pinCode', pinCode);
    put('panNumber', panNumber);
    put('gstin', gstin);
    if (isActive != null) data['isActive'] = isActive;
    return data;
  }
}
