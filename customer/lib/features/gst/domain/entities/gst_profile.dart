class GstProfile {
  const GstProfile({this.gstin, this.legalName});
  const GstProfile.empty() : gstin = null, legalName = null;

  final String? gstin;
  final String? legalName;

  bool get isComplete =>
      (gstin?.isNotEmpty ?? false) && (legalName?.isNotEmpty ?? false);

  factory GstProfile.fromJson(Map<String, dynamic> json) => GstProfile(
    gstin: json['gstin'] as String?,
    legalName: json['legalName'] as String?,
  );
}
