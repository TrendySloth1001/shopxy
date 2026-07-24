import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_shop.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';

/// Detail-level product as returned by `GET /marketplace/products/:id`.
/// Carries enough fields to render the V2 PDP: gallery, price/MRP +
/// derived discount, rating denorms, the owning shop, and
/// tags-as-highlights.
class MarketplaceProduct {
  const MarketplaceProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.mrp,
    required this.sellingPrice,
    required this.taxPercent,
    required this.stockQuantity,
    required this.images,
    required this.tags,
    required this.highlights,
    required this.specs,
    required this.offers,
    required this.totalSold,
    this.description,
    this.countryOfOrigin,
    this.ratingAvg,
    this.ratingCount = 0,
    this.shop,
    this.category,
    this.brand,
    this.soldLast30d = 0,
    this.systemTags = const [],
    this.contentBlocks = const [],
    this.variantAxes = const [],
    this.variants = const [],
    this.bankOffers = const [],
  });

  final String id;
  final String name;
  final String sku;
  final String unit;
  final double mrp;
  final double sellingPrice;
  final double taxPercent;
  final double stockQuantity;
  final List<String> images;
  final List<String> tags;

  /// Short above-the-fold bullets ("6.7-inch AMOLED", "7 years OS").
  /// Distinct from [tags] — those drive filtering; these drive
  /// presentation.
  final List<String> highlights;

  /// Long-form grouped spec sheet. Empty when the merchant hasn't
  /// filled one in; PDP collapses the section in that case.
  final List<SpecGroup> specs;

  /// Bank / coupon / EMI / exchange offers rendered beneath the
  /// price block.
  final List<ProductOffer> offers;
  final int totalSold;
  final String? description;

  /// Legal Metrology — country of origin (mandatory for imported goods),
  /// shown on the PDP before add-to-cart. Null for domestic items that
  /// leave it unset.
  final String? countryOfOrigin;
  final double? ratingAvg;
  final int ratingCount;
  final MarketplaceShop? shop;
  final ProductCategoryRef? category;

  /// Free-text brand surfaced under the title.
  final String? brand;

  /// Trailing-30-day sold quantity — drives "X bought in past month".
  final int soldLast30d;

  /// Curated system tags (BESTSELLER, EDITORS_PICK, NEW_ARRIVAL,
  /// TRENDING). Rendered as black pills above the title.
  final List<String> systemTags;

  /// A+ content blocks. Discriminated by `kind`; the renderer
  /// dispatches per kind and falls back to a "Unknown block" stub
  /// when it doesn't recognise the kind (forward-compat).
  final List<ContentBlock> contentBlocks;

  /// Phase E — variant axis definitions ({name, values}). Empty for
  /// single-variant products.
  final List<MarketplaceVariantAxis> variantAxes;

  /// Phase E — purchasable variant rows. Always has ≥1 entry; the
  /// default variant (attributes={}) is sentinel for flat-SKU
  /// products. The customer PDP renders a swatch picker only when
  /// `variants.length > 1`.
  final List<MarketplaceVariant> variants;

  /// Platform-curated bank offers eligible for this product. Curated
  /// centrally by admins, not by the owning shop — Amazon-style
  /// platform tie-ups (HDFC, ICICI, SBI…). Filtered server-side to
  /// offers whose `minOrderAmount` ≤ selling price + currently inside
  /// their validity window. May be empty.
  final List<PlatformBankOffer> bankOffers;

  /// Default variant — what the PDP shows before the customer picks
  /// anything. Always exists because every product has ≥1 variant.
  MarketplaceVariant? get defaultVariant {
    if (variants.isEmpty) return null;
    for (final v in variants) {
      if (v.isDefault) return v;
    }
    return variants.first;
  }

  bool get inStock => stockQuantity > 0;
  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;
  int get discountPct {
    if (mrp <= 0 || sellingPrice <= 0 || mrp <= sellingPrice) return 0;
    return (((mrp - sellingPrice) / mrp) * 100).round();
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MarketplaceProduct.fromJson(Map<String, dynamic> j) {
    final imageList = (j['images'] as List<dynamic>? ?? [])
        .map((e) => (e as Map<String, dynamic>)['url'] as String?)
        .whereType<String>()
        .toList();
    final specRaw = j['specs'];
    final offersRaw = j['offers'];
    return MarketplaceProduct(
      id: j['id'].toString(),
      name: j['name'] as String,
      sku: j['sku'] as String,
      unit: j['unit'] as String? ?? 'PCS',
      mrp: _asDouble(j['mrp']),
      sellingPrice: _asDouble(j['sellingPrice']),
      taxPercent: _asDouble(j['taxPercent']),
      stockQuantity: _asDouble(j['stockQuantity']),
      images: imageList,
      tags: (j['tags'] as List<dynamic>? ?? []).cast<String>(),
      highlights: (j['highlights'] as List<dynamic>? ?? []).cast<String>(),
      specs: specRaw is List
          ? specRaw
              .whereType<Map<String, dynamic>>()
              .map(SpecGroup.fromJson)
              .where((g) => g.rows.isNotEmpty)
              .toList()
          : const [],
      offers: offersRaw is List
          ? offersRaw
              .whereType<Map<String, dynamic>>()
              .map(ProductOffer.fromJson)
              .toList()
          : const [],
      totalSold: j['totalSold'] as int? ?? 0,
      description: j['description'] as String?,
      countryOfOrigin: (j['countryOfOrigin'] as String?)?.trim().isEmpty == false
          ? (j['countryOfOrigin'] as String).trim()
          : null,
      ratingAvg: j['ratingAvg'] == null ? null : _asDouble(j['ratingAvg']),
      ratingCount: j['ratingCount'] as int? ?? 0,
      shop: j['shop'] is Map<String, dynamic>
          ? MarketplaceShop.fromJson(j['shop'] as Map<String, dynamic>)
          : null,
      category: j['category'] is Map<String, dynamic>
          ? ProductCategoryRef.fromJson(j['category'] as Map<String, dynamic>)
          : null,
      brand: (j['brand'] as String?)?.trim().isEmpty == false
          ? (j['brand'] as String).trim()
          : null,
      soldLast30d: (j['soldLast30d'] as num?)?.toInt() ?? 0,
      systemTags:
          (j['systemTags'] as List<dynamic>?)?.cast<String>() ?? const [],
      contentBlocks: (j['contentBlocks'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ContentBlock.fromJson)
              .toList() ??
          const [],
      variantAxes: (j['variantAxes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MarketplaceVariantAxis.fromJson)
              .toList() ??
          const [],
      variants: (j['variants'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(MarketplaceVariant.fromJson)
              .toList() ??
          const [],
      bankOffers: (j['bankOffers'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(PlatformBankOffer.fromJson)
              .toList() ??
          const [],
    );
  }

}

/// Platform-curated bank offer surfaced on the PDP. Mirrors the
/// `platform_bank_offers` row shape — bank code, card type, discount
/// math and validity window. Discount application itself happens at
/// payment time (BIN lookup), so the customer only sees this as a
/// visible badge here.
class PlatformBankOffer {
  const PlatformBankOffer({
    required this.id,
    required this.bank,
    required this.cardType,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    required this.validUntil,
    this.maxDiscount,
    this.terms,
  });

  final String id;
  /// Short code matching the PDP renderer's bank set (HDFC, ICICI,
  /// SBI, AXIS, KOTAK, AMEX, YES, HSBC, SC, IDFC, BOB, RBL).
  final String bank;
  /// CREDIT | DEBIT | CREDIT_DEBIT | NET_BANKING | EMI | ANY.
  final String cardType;
  /// PERCENT or FLAT.
  final String discountType;
  final double discountValue;
  final double minOrderAmount;
  final DateTime validUntil;
  final double? maxDiscount;
  final String? terms;

  /// Friendly text for the offer card. Composed client-side so the
  /// backend stores the structured pieces, not a duplicated string.
  String get headline {
    final discount = discountType == 'PERCENT'
        ? '${discountValue.toStringAsFixed(0)}% off'
        : '${AppFormat.rupees(discountValue)} off';
    final capPart = (discountType == 'PERCENT' && maxDiscount != null)
        ? ' up to ${AppFormat.rupees(maxDiscount!)}'
        : '';
    final cardPart = _cardTypeLabel(cardType);
    return '$discount$capPart on ${bankDisplayName(bank)}$cardPart';
  }

  static String bankDisplayName(String code) {
    switch (code) {
      case 'HDFC':
        return 'HDFC Bank';
      case 'ICICI':
        return 'ICICI Bank';
      case 'SBI':
        return 'State Bank of India';
      case 'AXIS':
        return 'Axis Bank';
      case 'KOTAK':
        return 'Kotak Mahindra Bank';
      case 'AMEX':
        return 'American Express';
      case 'YES':
        return 'YES Bank';
      case 'HSBC':
        return 'HSBC';
      case 'SC':
        return 'Standard Chartered';
      case 'IDFC':
        return 'IDFC First Bank';
      case 'BOB':
        return 'Bank of Baroda';
      case 'RBL':
        return 'RBL Bank';
      default:
        return code;
    }
  }

  static String _cardTypeLabel(String code) {
    switch (code) {
      case 'CREDIT':
        return ' Credit Cards';
      case 'DEBIT':
        return ' Debit Cards';
      case 'CREDIT_DEBIT':
        return ' Credit & Debit Cards';
      case 'NET_BANKING':
        return ' Net Banking';
      case 'EMI':
        return ' EMI';
      case 'ANY':
      default:
        return '';
    }
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory PlatformBankOffer.fromJson(Map<String, dynamic> j) =>
      PlatformBankOffer(
        id: j['id'].toString(),
        bank: (j['bank'] as String?) ?? '',
        cardType: (j['cardType'] as String?) ?? 'ANY',
        discountType: (j['discountType'] as String?) ?? 'PERCENT',
        discountValue: _asDouble(j['discountValue']),
        minOrderAmount: _asDouble(j['minOrderAmount']),
        validUntil: DateTime.parse(j['validUntil'] as String),
        maxDiscount:
            j['maxDiscount'] == null ? null : _asDouble(j['maxDiscount']),
        terms: j['terms'] as String?,
      );
}

/// Phase E — variant axis definition surfaced to the customer client.
class MarketplaceVariantAxis {
  const MarketplaceVariantAxis({required this.name, required this.values});
  final String name;
  final List<String> values;

  factory MarketplaceVariantAxis.fromJson(Map<String, dynamic> j) =>
      MarketplaceVariantAxis(
        name: (j['name'] as String?) ?? '',
        values: ((j['values'] as List<dynamic>?) ?? const []).cast<String>(),
      );
}

/// Phase E — read-side variant payload. Single class on the customer
/// side; the cart add-to-cart payload includes [id] so the order
/// preserves which variant the customer chose.
class MarketplaceVariant {
  const MarketplaceVariant({
    required this.id,
    required this.sku,
    required this.attributes,
    required this.mrp,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.imageUrls,
    required this.isDefault,
  });

  final String id;
  final String sku;
  final Map<String, String> attributes;
  final double mrp;
  final double sellingPrice;
  final double stockQuantity;
  final List<String> imageUrls;
  final bool isDefault;

  bool get inStock => stockQuantity > 0;
  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;
  int get discountPct {
    if (mrp <= 0 || sellingPrice <= 0 || mrp <= sellingPrice) return 0;
    return (((mrp - sellingPrice) / mrp) * 100).round();
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MarketplaceVariant.fromJson(Map<String, dynamic> j) {
    final attrs = (j['attributes'] as Map?) ?? const {};
    return MarketplaceVariant(
      id: j['id'].toString(),
      sku: (j['sku'] as String?) ?? '',
      attributes: <String, String>{
        for (final e in attrs.entries)
          e.key.toString(): e.value?.toString() ?? '',
      },
      mrp: _asDouble(j['mrp']),
      sellingPrice: _asDouble(j['sellingPrice']),
      stockQuantity: _asDouble(j['stockQuantity']),
      imageUrls:
          ((j['imageUrls'] as List<dynamic>?) ?? const []).cast<String>(),
      isDefault: (j['isDefault'] as bool?) ?? false,
    );
  }
}

/// Phase G — slim product card returned by the FBT rail endpoint.
/// Same shape as the backend `listSelect`, no shop relation projection
/// since the rail is intra-shop already and we don't need the badge.
class MarketplaceFbtCard {
  const MarketplaceFbtCard({
    required this.id,
    required this.name,
    required this.sellingPrice,
    required this.mrp,
    required this.imageUrl,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  final String id;
  final String name;
  final double sellingPrice;
  final double mrp;
  final String? imageUrl;
  final double? ratingAvg;
  final int ratingCount;

  bool get isDiscounted => mrp > 0 && mrp > sellingPrice;

  static double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  factory MarketplaceFbtCard.fromJson(Map<String, dynamic> j) {
    final imgs = j['images'] as List<dynamic>? ?? const [];
    final firstUrl = imgs.isEmpty
        ? null
        : (imgs.first as Map<String, dynamic>)['url'] as String?;
    return MarketplaceFbtCard(
      id: j['id'].toString(),
      name: j['name'] as String,
      sellingPrice: _asDouble(j['sellingPrice']),
      mrp: _asDouble(j['mrp']),
      imageUrl: firstUrl,
      ratingAvg: j['ratingAvg'] == null ? null : _asDouble(j['ratingAvg']),
      ratingCount: j['ratingCount'] as int? ?? 0,
    );
  }
}

/// Phase C — A+ content block. Single class with a `kind` discriminator
/// and a free-form `data` map so the customer can render newer kinds
/// the server adds before the client release ships. Unknown kinds
/// collapse to a placeholder rather than crashing the PDP.
class ContentBlock {
  const ContentBlock({required this.kind, required this.data});
  final String kind;
  final Map<String, dynamic> data;

  factory ContentBlock.fromJson(Map<String, dynamic> j) {
    final copy = Map<String, dynamic>.from(j);
    final kind = (copy.remove('kind') as String?) ?? 'TEXT';
    return ContentBlock(kind: kind, data: copy);
  }
}

/// One section of the spec sheet — title plus N (label, value) rows.
/// Phase D: an optional [tab] bucket; when any group on a product
/// carries a tab the PDP renders a chip row above the table and
/// filters groups by selection. `null` ⇒ legacy flat list.
class SpecGroup {
  const SpecGroup({required this.title, this.tab, required this.rows});
  final String title;
  final String? tab;
  final List<SpecRow> rows;

  factory SpecGroup.fromJson(Map<String, dynamic> j) {
    final tabRaw = (j['tab'] as String?)?.trim();
    return SpecGroup(
      title: (j['title'] as String?) ?? '',
      tab: tabRaw == null || tabRaw.isEmpty ? null : tabRaw,
      rows: ((j['rows'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SpecRow.fromJson)
          .where((r) => r.label.isNotEmpty)
          .toList(),
    );
  }
}

class SpecRow {
  const SpecRow({required this.label, required this.value});
  final String label;
  final String value;

  factory SpecRow.fromJson(Map<String, dynamic> j) => SpecRow(
        label: (j['label'] as String?) ?? '',
        value: (j['value'] as String?) ?? '',
      );
}

/// A single bank / coupon / EMI / exchange offer.
class ProductOffer {
  const ProductOffer({
    required this.kind,
    required this.headline,
    this.detail,
    this.code,
  });

  /// 'BANK' | 'COUPON' | 'EMI' | 'EXCHANGE' — kept as a String so the
  /// customer model survives new server-side kinds without a client
  /// release. The PDP falls back to a generic icon for unknown kinds.
  final String kind;
  final String headline;
  final String? detail;
  final String? code;

  factory ProductOffer.fromJson(Map<String, dynamic> j) => ProductOffer(
        kind: (j['kind'] as String?) ?? 'COUPON',
        headline: (j['headline'] as String?) ?? '',
        detail: j['detail'] as String?,
        code: j['code'] as String?,
      );
}

class ProductCategoryRef {
  const ProductCategoryRef({required this.id, required this.name, required this.slug});
  final String id;
  final String name;
  final String slug;
  factory ProductCategoryRef.fromJson(Map<String, dynamic> j) =>
      ProductCategoryRef(id: j['id'].toString(), name: j['name'] as String, slug: j['slug'] as String);
}
