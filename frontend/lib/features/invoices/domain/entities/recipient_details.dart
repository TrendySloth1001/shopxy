class RecipientDetails {
  const RecipientDetails({
    this.address,
    this.city,
    this.state,
    this.stateCode,
    this.pinCode,
    this.acknowledgeMissing = false,
  });

  const RecipientDetails.acknowledgedMissing()
    : address = null,
      city = null,
      state = null,
      stateCode = null,
      pinCode = null,
      acknowledgeMissing = true;

  final String? address;
  final String? city;
  final String? state;
  final String? stateCode;
  final String? pinCode;
  final bool acknowledgeMissing;

  bool get hasAnyAddress => [
    address,
    city,
    state,
    stateCode,
    pinCode,
  ].any((v) => v != null && v.trim().isNotEmpty);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) json[key] = value.trim();
    }

    put('customerAddress', address);
    put('customerCity', city);
    put('customerState', state);
    put('customerStateCode', stateCode);
    put('customerPinCode', pinCode);
    if (acknowledgeMissing) json['acknowledgeMissingRecipientDetails'] = true;
    return json;
  }
}
