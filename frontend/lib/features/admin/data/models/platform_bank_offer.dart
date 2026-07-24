/// Mirror of the backend `platform_bank_offers` row. Decimals come
/// across the wire as strings (Prisma serialisation), so the parser
/// accepts both num and String for safety. Held as `double` once
/// parsed — the editor is a UI surface, not a money ledger.
class AdminPlatformBankOffer {
  const AdminPlatformBankOffer({
    required this.id,
    required this.bank,
    required this.cardType,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.validFrom,
    required this.validUntil,
    required this.isActive,
    this.maxDiscount,
    this.terms,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bank;
  final String cardType;
  final String discountType; // 'PERCENT' | 'FLAT'
  final double discountValue;
  final double minOrderAmount;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool isActive;
  final double? maxDiscount;
  final String? terms;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isExpired => validUntil.isBefore(DateTime.now());
  bool get isScheduled => validFrom.isAfter(DateTime.now());
  /// Returns 'Live' / 'Scheduled' / 'Expired' / 'Off' so the row tag
  /// matches the same vocabulary the banner manager uses.
  String get statusLabel {
    if (!isActive) return 'Off';
    if (isExpired) return 'Expired';
    if (isScheduled) return 'Scheduled';
    return 'Live';
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory AdminPlatformBankOffer.fromJson(Map<String, dynamic> j) =>
      AdminPlatformBankOffer(
        id: j['id'].toString(),
        bank: (j['bank'] as String?) ?? '',
        cardType: (j['cardType'] as String?) ?? 'ANY',
        discountType: (j['discountType'] as String?) ?? 'PERCENT',
        discountValue: _asDouble(j['discountValue']),
        minOrderAmount: _asDouble(j['minOrderAmount']),
        validFrom: DateTime.parse(j['validFrom'] as String),
        validUntil: DateTime.parse(j['validUntil'] as String),
        isActive: (j['isActive'] as bool?) ?? true,
        maxDiscount:
            j['maxDiscount'] == null ? null : _asDouble(j['maxDiscount']),
        terms: j['terms'] as String?,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.parse(j['createdAt'] as String),
        updatedAt: j['updatedAt'] == null
            ? null
            : DateTime.parse(j['updatedAt'] as String),
      );
}
