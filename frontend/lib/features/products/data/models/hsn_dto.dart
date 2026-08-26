library;

double _rate(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

class HsnNode {
  const HsnNode({required this.code, required this.name});
  final String code;
  final String name;

  factory HsnNode.fromJson(Map<String, dynamic> json) => HsnNode(
        code: '${json['code']}',
        name: json['name'] as String? ?? '',
      );
}

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

  final String per;

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

  final String kind;

  final String name;
  final double gstRate;
  final double cessRate;
  final String? definition;

  final String? rateNote;
  final HsnRateRule? rule;

  final List<HsnNode> breadcrumb;

  final List<HsnNode> notHere;

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

  final String requestedCode;

  final String code;
  final bool exact;
  final double gstRate;
  final double cessRate;

  final String source;

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

  final String label;
  final String code;
  final int useCount;

  final bool needsAttention;

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

String normalizeHsnCode(String raw) => raw.replaceAll(RegExp(r'\D'), '');

String formatHsnRate(double rate) {
  final asInt = rate.truncate();
  return rate == asInt ? '$asInt' : rate.toString();
}
