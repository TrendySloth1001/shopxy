/// Customer-owned delivery address. Mirrors `UserAddress` in the
/// backend Prisma schema. `isDefault` is the partial-unique-indexed
/// "ship here unless I pick a different one" flag.
class UserAddress {
  const UserAddress({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    required this.isDefault,
    this.label,
    this.line2,
    this.landmark,
  });

  final String id;
  final String? label;
  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  final bool isDefault;

  /// Single-line representation for the top-bar location chip and
  /// order-summary blocks. Skips null parts cleanly.
  String get oneLine {
    final parts = <String>[line1, if (line2 != null && line2!.isNotEmpty) line2!, '$city $pincode'];
    return parts.join(', ');
  }

  factory UserAddress.fromJson(Map<String, dynamic> j) => UserAddress(
        id: j['id'].toString(),
        label: j['label'] as String?,
        fullName: j['fullName'] as String,
        phone: j['phone'] as String,
        line1: j['line1'] as String,
        line2: j['line2'] as String?,
        city: j['city'] as String,
        state: j['state'] as String,
        pincode: j['pincode'] as String,
        landmark: j['landmark'] as String?,
        isDefault: j['isDefault'] as bool? ?? false,
      );
}

/// Wire-format input for create + update. Nullable fields go on as
/// `null` (not omitted) so the backend can explicitly clear them
/// — distinguishing "leave alone" from "set to empty" is necessary
/// once we add inline edit affordances.
class UserAddressInput {
  const UserAddressInput({
    required this.fullName,
    required this.phone,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.label,
    this.line2,
    this.landmark,
    this.isDefault,
  });

  final String? label;
  final String fullName;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  final bool? isDefault;

  Map<String, dynamic> toJson() => {
        if (label != null) 'label': label,
        'fullName': fullName,
        'phone': phone,
        'line1': line1,
        if (line2 != null) 'line2': line2,
        'city': city,
        'state': state,
        'pincode': pincode,
        if (landmark != null) 'landmark': landmark,
        if (isDefault != null) 'isDefault': isDefault,
      };
}
