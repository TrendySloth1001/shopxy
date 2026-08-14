import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/features/home/domain/banner_link.dart';

/// These cases mirror `backend/tests/banners/banner-link.test.ts` exactly. The
/// grammar is duplicated across three codebases, so the tests are duplicated
/// too — a divergence shows up here rather than as a banner that silently
/// stops working in the field.
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
      // The old code passed these to the search box as a literal query, so a
      // banner linking to a URL searched for the text of its own URL.
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
