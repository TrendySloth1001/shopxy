/// A merchant the customer is linked to — distinct from `LinkedShop`
/// (the legacy party/vendor-row entity) in that this represents the
/// Shop itself, ready to deep-link into the marketplace ShopProfilePage.
///
/// Returned by `GET /me/linked-shops`.
class LinkedMerchant {
  const LinkedMerchant({
    required this.shopId,
    required this.ownerUserId,
    required this.name,
    required this.slug,
    required this.isPublished,
    required this.linkedAsParty,
    required this.linkedAsVendor,
    this.tagline,
    this.logoUrl,
    this.bannerUrl,
    this.rating,
    this.ratingCount = 0,
  });

  /// Marketplace `Shop.id` — distinct from the merchant owner's userId.
  final int shopId;

  /// Owner User.id of the shop. Used by the customer app to skip its
  /// own shop on browse pages (the "can't buy from your own shop" rule
  /// is enforced server-side; this is just a UI nicety).
  final int ownerUserId;

  final String name;

  /// URL-safe identifier — pushed into `ShopProfilePage(slug)`.
  final String slug;

  /// When false, the shop hasn't gone fully public yet but the customer
  /// can still browse it because they have an explicit link.
  final bool isPublished;

  /// True when the user is linked as a Party (i.e. a customer of this
  /// merchant) — invoices issued *to* them live here.
  final bool linkedAsParty;

  /// True when the user is linked as a Vendor (i.e. they supply this
  /// merchant). Future Vendor portal will hang off this flag.
  final bool linkedAsVendor;

  final String? tagline;
  final String? logoUrl;
  final String? bannerUrl;
  final double? rating;
  final int ratingCount;

  factory LinkedMerchant.fromJson(Map<String, dynamic> j) {
    final roles = j['roles'] as Map<String, dynamic>? ?? const {};
    return LinkedMerchant(
      shopId: j['id'] as int,
      ownerUserId: j['ownerUserId'] as int,
      name: j['name'] as String,
      slug: j['slug'] as String,
      isPublished: j['isPublished'] as bool? ?? false,
      linkedAsParty: roles['party'] as bool? ?? false,
      linkedAsVendor: roles['vendor'] as bool? ?? false,
      tagline: j['tagline'] as String?,
      logoUrl: j['logoUrl'] as String?,
      bannerUrl: j['bannerUrl'] as String?,
      rating: _d(j['rating']),
      ratingCount: j['ratingCount'] as int? ?? 0,
    );
  }

  static double? _d(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
