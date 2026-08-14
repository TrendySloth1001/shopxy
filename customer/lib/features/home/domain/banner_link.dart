/// Where a banner sends you when it's tapped.
///
/// Mirrors `backend/src/modules/banners/banner-link.ts`. Keep the two in step:
/// the API stores only what it can parse, and anything this can't parse is
/// treated as decorative rather than guessed at.
///
/// Grammar — `<kind>:<value>`:
///   `product:<publicId>`   a product's detail page
///   `category:<slug>`      a category listing
///   `shop:<slug>`          a seller's storefront
///   `search:<query>`       search results for a phrase
enum BannerLinkKind { product, category, shop, search }

class BannerLink {
  const BannerLink(this.kind, this.value);
  final BannerLinkKind kind;
  final String value;

  static final _slug = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
  static final _publicId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static const _maxSearchLength = 120;

  /// Returns null for anything unrecognised — including the legacy
  /// `https://…` and `/path` values, which used to be fed to the search box
  /// as a literal query so a URL banner searched for the text of its own URL.
  static BannerLink? parse(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    final separator = trimmed.indexOf(':');
    if (separator <= 0) return null;

    final kind = trimmed.substring(0, separator).toLowerCase();
    final value = trimmed.substring(separator + 1).trim();
    if (value.isEmpty) return null;

    switch (kind) {
      case 'product':
        return _publicId.hasMatch(value)
            ? BannerLink(BannerLinkKind.product, value)
            : null;
      case 'category':
        return _slug.hasMatch(value.toLowerCase())
            ? BannerLink(BannerLinkKind.category, value.toLowerCase())
            : null;
      case 'shop':
        return _slug.hasMatch(value.toLowerCase())
            ? BannerLink(BannerLinkKind.shop, value.toLowerCase())
            : null;
      case 'search':
        return value.length <= _maxSearchLength
            ? BannerLink(BannerLinkKind.search, value)
            : null;
      default:
        return null;
    }
  }

  @override
  String toString() => '${kind.name}:$value';

  @override
  bool operator ==(Object other) =>
      other is BannerLink && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}
