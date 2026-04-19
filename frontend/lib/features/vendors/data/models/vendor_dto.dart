import 'package:shopxy/features/vendors/domain/entities/vendor.dart';

class VendorDto {
  static Vendor fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return Vendor(
      id: json['id'] as int,
      name: json['name'] as String,
      contactName: json['contactName'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      gstin: json['gstin'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      transactionCount: count?['stockTransactions'] as int? ?? 0,
      invoiceCount: count?['invoices'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> toCreateJson({
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
  }) {
    final data = <String, dynamic>{
      'name': name,
      if (contactName != null && contactName.isNotEmpty) 'contactName': contactName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (address != null && address.isNotEmpty) 'address': address,
      if (gstin != null && gstin.isNotEmpty) 'gstin': gstin,
    };
    return data;
  }

  static Map<String, dynamic> toUpdateJson({
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    bool? isActive,
  }) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (contactName != null) data['contactName'] = contactName.isEmpty ? null : contactName;
    if (phone != null) data['phone'] = phone.isEmpty ? null : phone;
    if (email != null) data['email'] = email.isEmpty ? null : email;
    if (address != null) data['address'] = address.isEmpty ? null : address;
    if (gstin != null) data['gstin'] = gstin.isEmpty ? null : gstin;
    if (isActive != null) data['isActive'] = isActive;
    return data;
  }
}
