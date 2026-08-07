/// The recipient's postal identity, carried from the invoice form to the API.
///
/// GST Rule 46(e)/(f) makes the recipient's name AND address mandatory once an
/// invoice is B2B (recipient GSTIN present) or worth ≥ ₹50,000. Until now the
/// address could only reach an invoice through the linked Party row, so a
/// party saved without one made such an invoice unsavable from the form —
/// the backend rejected it and there was nowhere to put the missing address.
///
/// Fields left null fall back to the party on the server; supplied ones win.
class RecipientDetails {
  const RecipientDetails({
    this.address,
    this.city,
    this.state,
    this.stateCode,
    this.pinCode,
    this.acknowledgeMissing = false,
  });

  /// The merchant was shown exactly which details were missing, told the
  /// invoice won't meet Rule 46(e)/(f) without them, and chose to issue it
  /// anyway. Nothing else may set this — it is a deliberate, informed
  /// compliance exception, not a convenience default.
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

  /// True when at least one postal field carries something — the same shape of
  /// question the server's guard asks.
  bool get hasAnyAddress => [
    address,
    city,
    state,
    stateCode,
    pinCode,
  ].any((v) => v != null && v.trim().isNotEmpty);

  /// The wire fields, omitting anything empty so the server's
  /// "supplied wins, else fall back to the party" precedence still applies to
  /// the fields the merchant left blank.
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
