/// Client-side view of the HSN/SAC rate master.
///
/// The merchant answers one question — what is this product? — and the GST rate
/// follows. Nothing here lets them type a rate; that path exists only as the
/// explicit manual escape hatch on the product form, and it is recorded as such.
///
/// Mirrors `backend/src/modules/hsn/hsn.service.ts`. Rates arrive as JSON
/// numbers and are read through `num` so an integer 5 and a decimal 5.0 both
/// parse.
library;

double _rate(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// One level of the tariff tree — a chapter, a heading, or a cross-reference.
class HsnNode {
  const HsnNode({required this.code, required this.name});
  final String code;
  final String name;

  factory HsnNode.fromJson(Map<String, dynamic> json) => HsnNode(
        code: '${json['code']}',
        name: json['name'] as String? ?? '',
      );
}

/// A slab that turns on price. Apparel is 5% up to ₹2,500 a piece and 18%
/// above — arithmetic against a number we hold, so the server decides it rather
/// than printing a note and hoping the merchant reads it.
class HsnRateRule {
  const HsnRateRule({
    required this.threshold,
    required this.atOrBelow,
    required this.above,
    required this.per,
    this.testedPrice,
  });

  final double threshold;
  final double atOrBelow;
  final double above;

  /// 'PIECE' | 'PAIR' | 'UNIT_PER_DAY' — what the threshold is measured
  /// against, for the explanation shown to the merchant.
  final String per;

  /// The price the threshold was actually tested against, when the server had
  /// one. Null means the rule is a condition we're reporting, not a decision
  /// we've made.
  final double? testedPrice;

  factory HsnRateRule.fromJson(Map<String, dynamic> json) => HsnRateRule(
        threshold: _rate(json['threshold']),
        atOrBelow: _rate(json['atOrBelow']),
        above: _rate(json['above']),
        per: json['per'] as String? ?? 'PIECE',
        testedPrice:
            json['testedPrice'] == null ? null : _rate(json['testedPrice']),
      );
}

/// A code as shown in the picker: what it is, what it bills at, and where it
/// sits in the tariff.
class HsnMatch {
  const HsnMatch({
    required this.code,
    required this.kind,
    required this.name,
    required this.gstRate,
    required this.cessRate,
    this.definition,
    this.rateNote,
    this.rule,
    this.breadcrumb = const [],
    this.notHere = const [],
    this.fromShortcut = false,
  });

  final String code;

  /// 'GOODS' (HSN) or 'SERVICES' (SAC).
  final String kind;

  /// Plain-language label from the translated copy catalogue, falling back to
  /// official tariff wording.
  final String name;
  final double gstRate;
  final double cessRate;
  final String? definition;

  /// Advisory caveat for conditions the server can't evaluate — packaging,
  /// engine capacity, end use.
  final String? rateNote;
  final HsnRateRule? rule;

  /// Chapter → heading. Shown above the name because a four-digit code alone
  /// can't tell anyone that chapter 62 is woven and 61 is knitted, which is the
  /// most common apparel misclassification there is.
  final List<HsnNode> breadcrumb;

  /// "Not this? try these" — the neighbours this code gets confused with.
  final List<HsnNode> notHere;

  /// True when this came from the merchant's own saved codes.
  final bool fromShortcut;

  static List<HsnNode> _nodes(Object? raw) => (raw as List? ?? const [])
      .map((e) => HsnNode.fromJson(e as Map<String, dynamic>))
      .toList();

  factory HsnMatch.fromJson(Map<String, dynamic> json) => HsnMatch(
        code: '${json['code']}',
        kind: json['kind'] as String? ?? 'GOODS',
        name: json['name'] as String? ?? '',
        gstRate: _rate(json['gstRate']),
        cessRate: _rate(json['cessRate']),
        definition: json['definition'] as String?,
        rateNote: json['rateNote'] as String?,
        rule: json['rule'] == null
            ? null
            : HsnRateRule.fromJson(json['rule'] as Map<String, dynamic>),
        breadcrumb: _nodes(json['breadcrumb']),
        notHere: _nodes(json['notHere']),
        fromShortcut: json['fromShortcut'] as bool? ?? false,
      );
}

/// A [HsnMatch] proposed from the product name, tagged with how we got there.
class HsnSuggestion extends HsnMatch {
  const HsnSuggestion({
    required super.code,
    required super.kind,
    required super.name,
    required super.gstRate,
    required super.cessRate,
    super.definition,
    super.rateNote,
    super.rule,
    super.breadcrumb,
    super.notHere,
    super.fromShortcut,
    required this.via,
  });

  /// 'SHORTCUT' — this shop saved it · 'ALIAS' — matched the shared vocabulary
  /// · 'SEMANTIC' — a meaning-based guess. Worth surfacing: a code the merchant
  /// saved themselves deserves more trust than one we inferred.
  final String via;

  factory HsnSuggestion.fromJson(Map<String, dynamic> json) {
    final base = HsnMatch.fromJson(json);
    return HsnSuggestion(
      code: base.code,
      kind: base.kind,
      name: base.name,
      gstRate: base.gstRate,
      cessRate: base.cessRate,
      definition: base.definition,
      rateNote: base.rateNote,
      rule: base.rule,
      breadcrumb: base.breadcrumb,
      notHere: base.notHere,
      fromShortcut: base.fromShortcut,
      via: json['via'] as String? ?? 'ALIAS',
    );
  }
}

/// The answer to "what rate does this code bill at".
class HsnResolution {
  const HsnResolution({
    required this.requestedCode,
    required this.code,
    required this.exact,
    required this.gstRate,
    required this.cessRate,
    required this.source,
    required this.revision,
    this.rateNote,
    this.rule,
    this.breadcrumb = const [],
  });

  /// What was asked for, normalised to digits.
  final String requestedCode;

  /// The code the rate came from — a shorter heading when we don't carry the
  /// exact tariff item.
  final String code;
  final bool exact;
  final double gstRate;
  final double cessRate;

  /// 'HSN' — the code's flat rate · 'HSN_RULE' — decided by price ·
  /// 'OVERRIDE' — this shop's own recorded position.
  final String source;

  /// Which revision of the master produced this. Stored on the product so a
  /// later correction can be scoped exactly.
  final String revision;
  final String? rateNote;
  final HsnRateRule? rule;
  final List<HsnNode> breadcrumb;

  factory HsnResolution.fromJson(Map<String, dynamic> json) => HsnResolution(
        requestedCode: '${json['requestedCode'] ?? json['code']}',
        code: '${json['code']}',
        exact: json['exact'] as bool? ?? false,
        gstRate: _rate(json['gstRate']),
        cessRate: _rate(json['cessRate']),
        source: json['source'] as String? ?? 'HSN',
        revision: json['revision'] as String? ?? '',
        rateNote: json['rateNote'] as String?,
        rule: json['rule'] == null
            ? null
            : HsnRateRule.fromJson(json['rule'] as Map<String, dynamic>),
        breadcrumb: (json['breadcrumb'] as List? ?? const [])
            .map((e) => HsnNode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One of the merchant's own saved codes: "when I say X, I mean this code".
///
/// Carries no stored rate — [gstRate] and [name] are joined on live by the
/// server at read time. That is the whole safety property: there is nothing of
/// the merchant's holding a stale number, so a Council revision reaches them
/// without anyone rewriting their data.
class HsnShortcut {
  const HsnShortcut({
    required this.id,
    required this.label,
    required this.code,
    required this.useCount,
    required this.needsAttention,
    this.name,
    this.gstRate,
  });

  final String id;

  /// The merchant's own wording, exactly as they typed it.
  final String label;
  final String code;
  final int useCount;

  /// True when the saved code no longer resolves — a tariff revision retired or
  /// split it. The successor is a judgement call the merchant has to make.
  final bool needsAttention;

  /// Null alongside [needsAttention] — there is no live row to read a name or
  /// a rate from.
  final String? name;
  final double? gstRate;

  factory HsnShortcut.fromJson(Map<String, dynamic> json) => HsnShortcut(
        id: '${json['id']}',
        label: json['label'] as String? ?? '',
        code: '${json['code']}',
        useCount: (json['useCount'] as num?)?.toInt() ?? 0,
        needsAttention: json['needsAttention'] as bool? ?? false,
        name: json['name'] as String?,
        gstRate: json['gstRate'] == null ? null : _rate(json['gstRate']),
      );
}

/// A recorded departure from the platform rate for one code.
///
/// Heavier than a shortcut on purpose: a shortcut is a bookmark, this restates
/// the shop's tax position across the whole catalogue, so [reason] is mandatory
/// server-side and deletion is soft.
class HsnOverride {
  const HsnOverride({
    required this.id,
    required this.code,
    required this.gstRate,
    required this.cessRate,
    required this.reason,
    required this.effectiveFrom,
    this.effectiveTo,
  });

  final String id;
  final String code;
  final double gstRate;
  final double cessRate;

  /// The stated basis. An override without one can't be told apart from a typo,
  /// and this is the field an auditor asks about first.
  final String reason;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

  factory HsnOverride.fromJson(Map<String, dynamic> json) => HsnOverride(
        id: '${json['id']}',
        code: '${json['code']}',
        gstRate: _rate(json['gstRate']),
        cessRate: _rate(json['cessRate']),
        reason: json['reason'] as String? ?? '',
        effectiveFrom: DateTime.tryParse('${json['effectiveFrom'] ?? ''}'),
        effectiveTo: DateTime.tryParse('${json['effectiveTo'] ?? ''}'),
      );
}

/// HSN/SAC codes are digits only; merchants paste them with spaces and dots.
/// Mirrors `normalizeHsn` on the backend so both ends agree what counts as the
/// same code.
String normalizeHsnCode(String raw) => raw.replaceAll(RegExp(r'\D'), '');

/// 5.0 → "5", 0.25 → "0.25". Rates are stored as decimals but read as slabs.
String formatHsnRate(double rate) {
  final asInt = rate.truncate();
  return rate == asInt ? '$asInt' : rate.toString();
}
