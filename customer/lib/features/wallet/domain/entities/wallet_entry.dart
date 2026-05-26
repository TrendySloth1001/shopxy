double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.amount,
    required this.balanceAfter,
    required this.source,
    required this.description,
    required this.createdAt,
    this.sourceId,
  });

  final int id;
  /// Signed — positive credit, negative debit.
  final double amount;
  final double balanceAfter;
  /// REFUND / COUPON / REFERRAL / LOYALTY / MANUAL / CHECKOUT.
  final String source;
  final int? sourceId;
  final String description;
  final DateTime createdAt;

  bool get isCredit => amount > 0;

  factory WalletEntry.fromJson(Map<String, dynamic> j) => WalletEntry(
        id: j['id'] as int,
        amount: _d(j['amount']),
        balanceAfter: _d(j['balanceAfter']),
        source: j['source'] as String,
        sourceId: j['sourceId'] as int?,
        description: (j['description'] as String?) ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class WalletSnapshot {
  const WalletSnapshot({required this.balance, required this.entries});
  final double balance;
  final List<WalletEntry> entries;

  factory WalletSnapshot.fromJson(Map<String, dynamic> j) => WalletSnapshot(
        balance: _d(j['balance']),
        entries: ((j['entries'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WalletEntry.fromJson)
            .toList(),
      );
}
