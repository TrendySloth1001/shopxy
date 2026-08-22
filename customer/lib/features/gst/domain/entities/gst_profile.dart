/// The customer's own GST registration, used to claim input tax credit on
/// marketplace purchases. Both fields move together — a GSTIN with no
/// registered name cannot go on a tax invoice.
class GstProfile {
  const GstProfile({this.gstin, this.legalName});
  const GstProfile.empty() : gstin = null, legalName = null;

  final String? gstin;
  final String? legalName;

  /// Whether this account can claim input credit at all.
  bool get isComplete =>
      (gstin?.isNotEmpty ?? false) && (legalName?.isNotEmpty ?? false);

  factory GstProfile.fromJson(Map<String, dynamic> json) => GstProfile(
    gstin: json['gstin'] as String?,
    legalName: json['legalName'] as String?,
  );
}
