library;

class IndianValidators {
  IndianValidators._();

  static final RegExp gstinRegex =
      RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[0-9A-Z]{1}Z[0-9A-Z]{1}$');

  static final RegExp panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');

  static final RegExp pincodeRegex = RegExp(r'^[1-9][0-9]{5}$');

  static final RegExp phoneRegex =
      RegExp(r'^(?:\+?91[-\s]?|0)?[6-9][0-9]{9}$');

  static final RegExp hsnRegex = RegExp(r'^[0-9]{4}(?:[0-9]{2}(?:[0-9]{2})?)?$');

  static final RegExp upiVpaRegex =
      RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z]{2,64}$');

  static String? gstin(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return gstinRegex.hasMatch(t) ? null : 'Invalid GSTIN';
  }

  static String? pan(String? v) {
    final t = (v ?? '').trim().toUpperCase();
    if (t.isEmpty) return null;
    return panRegex.hasMatch(t) ? null : 'Invalid PAN';
  }

  static String? pincode(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return pincodeRegex.hasMatch(t) ? null : 'Invalid PIN code';
  }

  static String? phone(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return phoneRegex.hasMatch(t) ? null : 'Invalid phone number';
  }

  static String? hsn(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return hsnRegex.hasMatch(t) ? null : 'HSN must be 4, 6 or 8 digits';
  }

  static String? upiVpa(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return upiVpaRegex.hasMatch(t) ? null : 'Invalid UPI ID';
  }
}

typedef IndianState = ({String code, String name});

class IndianStates {
  IndianStates._();

  static const List<IndianState> all = [
    (code: '01', name: 'Jammu and Kashmir'),
    (code: '02', name: 'Himachal Pradesh'),
    (code: '03', name: 'Punjab'),
    (code: '04', name: 'Chandigarh'),
    (code: '05', name: 'Uttarakhand'),
    (code: '06', name: 'Haryana'),
    (code: '07', name: 'Delhi'),
    (code: '08', name: 'Rajasthan'),
    (code: '09', name: 'Uttar Pradesh'),
    (code: '10', name: 'Bihar'),
    (code: '11', name: 'Sikkim'),
    (code: '12', name: 'Arunachal Pradesh'),
    (code: '13', name: 'Nagaland'),
    (code: '14', name: 'Manipur'),
    (code: '15', name: 'Mizoram'),
    (code: '16', name: 'Tripura'),
    (code: '17', name: 'Meghalaya'),
    (code: '18', name: 'Assam'),
    (code: '19', name: 'West Bengal'),
    (code: '20', name: 'Jharkhand'),
    (code: '21', name: 'Odisha'),
    (code: '22', name: 'Chhattisgarh'),
    (code: '23', name: 'Madhya Pradesh'),
    (code: '24', name: 'Gujarat'),
    (code: '25', name: 'Daman and Diu'),
    (code: '26', name: 'Dadra and Nagar Haveli'),
    (code: '27', name: 'Maharashtra'),
    (code: '28', name: 'Andhra Pradesh (Before Division)'),
    (code: '29', name: 'Karnataka'),
    (code: '30', name: 'Goa'),
    (code: '31', name: 'Lakshadweep'),
    (code: '32', name: 'Kerala'),
    (code: '33', name: 'Tamil Nadu'),
    (code: '34', name: 'Puducherry'),
    (code: '35', name: 'Andaman and Nicobar Islands'),
    (code: '36', name: 'Telangana'),
    (code: '37', name: 'Andhra Pradesh (New)'),
    (code: '38', name: 'Ladakh'),
  ];

  static String? stateNameFromCode(String? code) {
    if (code == null || code.isEmpty) return null;
    for (final s in all) {
      if (s.code == code) return s.name;
    }
    return null;
  }

  static String? stateCodeFromGstin(String? gstin) {
    final trimmed = (gstin ?? '').trim();
    if (trimmed.length < 2) return null;
    final prefix = trimmed.substring(0, 2);
    for (final s in all) {
      if (s.code == prefix) return s.code;
    }
    return null;
  }

  static String? stateCodeFromName(String? name) {
    if (name == null || name.isEmpty) return null;
    final lc = name.toLowerCase();
    for (final s in all) {
      if (s.name.toLowerCase() == lc) return s.code;
    }
    return null;
  }
}
