import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/features/home/domain/banner_link.dart';

void main() {
  group('BannerLink.parse', () {
    test('parses each supported kind', () {
      expect(
        BannerLink.parse('product:sp2rhACi'),
        const BannerLink(BannerLinkKind.product, 'sp2rhACi'),
      );
      expect(
        BannerLink.parse('category:home-kitchen'),
        const BannerLink(BannerLinkKind.category, 'home-kitchen'),
      );
      expect(
        BannerLink.parse('shop:sharma-electronics'),
        const BannerLink(BannerLinkKind.shop, 'sharma-electronics'),
      );
      expect(
        BannerLink.parse('search:winter jackets'),
        const BannerLink(BannerLinkKind.search, 'winter jackets'),
      );
    });

    test('tolerates whitespace and kind casing', () {
      expect(
        BannerLink.parse('  Category: Home-Kitchen  '),
        const BannerLink(BannerLinkKind.category, 'home-kitchen'),
      );
    });

    test('keeps a search phrase verbatim', () {
      expect(
        BannerLink.parse('search:Winter Jackets'),
        const BannerLink(BannerLinkKind.search, 'Winter Jackets'),
      );
    });

    test('returns null for the legacy formats rather than guessing', () {
      expect(BannerLink.parse('https://example.com/sale'), isNull);
      expect(BannerLink.parse('/shop/acme'), isNull);
      expect(BannerLink.parse('url:https://example.com'), isNull);
    });

    test('rejects unknown kinds and malformed values', () {
      expect(BannerLink.parse('collection:summer'), isNull);
      expect(BannerLink.parse('category:Home Kitchen'), isNull);
      expect(BannerLink.parse('category:home_kitchen'), isNull);
      expect(BannerLink.parse('shop:-leading-hyphen'), isNull);
      expect(BannerLink.parse('product:has spaces'), isNull);
    });

    test('rejects empty, missing and separator-less input', () {
      expect(BannerLink.parse(null), isNull);
      expect(BannerLink.parse(''), isNull);
      expect(BannerLink.parse('   '), isNull);
      expect(BannerLink.parse('product:'), isNull);
      expect(BannerLink.parse('product'), isNull);
      expect(BannerLink.parse(':value'), isNull);
    });

    test('caps a search phrase', () {
      expect(BannerLink.parse('search:${'a' * 120}'), isNotNull);
      expect(BannerLink.parse('search:${'a' * 121}'), isNull);
    });

    test('round-trips through toString', () {
      for (final raw in [
        'product:sp2rhACi',
        'category:home-kitchen',
        'shop:sharma-electronics',
        'search:winter jackets',
      ]) {
        final parsed = BannerLink.parse(raw)!;
        expect(parsed.toString(), raw);
        expect(BannerLink.parse(parsed.toString()), parsed);
      }
    });
  });
}
