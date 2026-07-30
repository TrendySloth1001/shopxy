// Local product search over the preloaded catalogue.
//
// The pickers used to ask the server per keystroke — debounced, so the request
// count was sane, but the merchant still waited for the network before seeing
// a row. This holds the shop's active products in memory and answers in-frame.
//
// The dangerous failure here is not "slow", it's "confidently wrong": a
// catalogue that is partial, stale, or belongs to the previous user will
// happily tell a merchant their own SKU doesn't exist. Most of what follows
// tests refusal — when the index must decline to answer so the caller falls
// back to the server.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/presentation/providers/product_catalogue.dart';

Map<String, dynamic> _row(
  int id,
  String name,
  String sku, {
  String? barcode,
  double price = 100,
}) => {
  'id': id,
  'name': name,
  'sku': sku,
  'barcode': barcode,
  'hsnCode': null,
  'unit': 'PCS',
  'mrp': price,
  'sellingPrice': price,
  'purchasePrice': price / 2,
  'taxPercent': 5,
  'cessRate': 0,
  'taxSource': 'HSN',
  'stockQuantity': 10,
  'lowStockThreshold': 2,
  'categoryId': null,
  'isActive': true,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
};

/// Catalogue over a canned response. Returns the request counter so a test can
/// assert how many times the network was actually touched.
({ProductCatalogue catalogue, int Function() calls}) build({
  List<Map<String, dynamic>>? rows,
  bool truncated = false,
  int? total,
  int status = 200,
  bool throwing = false,
}) {
  var calls = 0;
  final data = rows ?? [];
  final api = ApiClient(
    TokenManager(),
    httpClient: MockClient((_) async {
      calls++;
      if (throwing) throw http.ClientException('offline');
      return http.Response(
        jsonEncode({
          'data': data,
          'total': total ?? data.length,
          'truncated': truncated,
        }),
        status,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  return (
    catalogue: ProductCatalogue(ProductsRemoteDataSource(api)),
    calls: () => calls,
  );
}

final _shop = [
  _row(1, 'Sugar 1 kg', 'SUG-1'),
  _row(2, 'Sugar 5 kg', 'SUG-5'),
  _row(3, 'Blue Pen', 'PEN-BLU', barcode: '8901234567890'),
  _row(4, 'Red Pen', 'PEN-RED'),
  _row(5, 'Notebook A4', 'NB-A4'),
  _row(6, 'Basmati Rice 5kg', 'RICE-B5'),
];

void main() {
  group('answers locally', () {
    test('finds a product by the start of its name', () async {
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.isSearchable, isTrue);
      expect(
        b.catalogue.search('sug').map((p) => p.sku),
        containsAll(<String>['SUG-1', 'SUG-5']),
      );
    });

    test('matches a word anywhere in the name, not just the first', () async {
      // A merchant reaching for "Basmati Rice 5kg" often types "rice" first.
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.search('rice').first.sku, 'RICE-B5');
    });

    test('an exact code outranks any name similarity', () async {
      // A scan or a fully-typed code is an unambiguous answer. It must win, or
      // scanning a barcode surfaces a list to choose from.
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.search('8901234567890').first.sku, 'PEN-BLU');
      expect(b.catalogue.search('pen-red').first.sku, 'PEN-RED');
    });

    test('every token must match — two words narrow, not widen', () async {
      // "blue pen" must not return every pen. An OR here would make the second
      // word actively unhelpful.
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      final hits = b.catalogue.search('blue pen');
      expect(hits, hasLength(1));
      expect(hits.first.sku, 'PEN-BLU');
    });

    test('ranks stably, so results do not reshuffle between keystrokes', () async {
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      expect(
        b.catalogue.search('sug').map((p) => p.sku).toList(),
        b.catalogue.search('sug').map((p) => p.sku).toList(),
      );
    });

    test('honours the limit', () async {
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.search('e', limit: 2), hasLength(2));
    });

    test('a blank query matches nothing rather than everything', () async {
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.search(''), isEmpty);
      expect(b.catalogue.search('   '), isEmpty);
    });

    test('nonsense matches nothing', () async {
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.search('zzzzqqq'), isEmpty);
    });
  });

  group('refuses to answer, so the caller asks the server', () {
    test('before it has loaded', () {
      final b = build(rows: _shop);

      expect(b.catalogue.isSearchable, isFalse);
      expect(b.catalogue.search('sugar'), isEmpty);
    });

    test('when the shop is larger than one response', () async {
      // The whole point: searching a partial catalogue would report a real
      // product as missing. Being unable to answer is the correct outcome.
      final b = build(rows: _shop, truncated: true, total: 90000);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.isTruncated, isTrue);
      expect(b.catalogue.isSearchable, isFalse);
      // Even though "Sugar 1 kg" is demonstrably in the rows it holds.
      expect(b.catalogue.search('sugar'), isEmpty);
    });

    test('when the load failed', () async {
      final b = build(throwing: true);
      await b.catalogue.ensureLoaded();

      expect(b.catalogue.isSearchable, isFalse);
      expect(b.catalogue.search('sugar'), isEmpty);
    });

    test('after logout', () async {
      // User B must never search user A's products.
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();
      expect(b.catalogue.search('sugar'), isNotEmpty);

      b.catalogue.reset();

      expect(b.catalogue.isSearchable, isFalse);
      expect(b.catalogue.search('sugar'), isEmpty);
      expect(b.catalogue.length, 0);
    });
  });

  group('loading', () {
    test('ensureLoaded fetches once however many pickers ask', () async {
      final b = build(rows: _shop);

      await Future.wait([
        b.catalogue.ensureLoaded(),
        b.catalogue.ensureLoaded(),
        b.catalogue.ensureLoaded(),
      ]);
      await b.catalogue.ensureLoaded();

      expect(b.calls(), 1);
    });

    test('refresh picks up a product added elsewhere', () async {
      // A create on the web app invalidates the `products` cache tag, and the
      // central listener calls refresh() — the merchant must not have to
      // restart the app to bill something they just added.
      final rows = [..._shop];
      final b = build(rows: rows);
      await b.catalogue.ensureLoaded();
      expect(b.catalogue.search('cardamom'), isEmpty);

      rows.add(_row(7, 'Cardamom 100g', 'CARD-100'));
      await b.catalogue.refresh();

      expect(b.catalogue.search('cardamom').first.sku, 'CARD-100');
    });

    test('a failed refresh keeps the catalogue it already had', () async {
      // Going offline mid-session must not empty a working index — a stale
      // list beats no list, and the rows are the merchant's own.
      var fail = false;
      var calls = 0;
      final api = ApiClient(
        TokenManager(),
        httpClient: MockClient((_) async {
          calls++;
          if (fail) throw http.ClientException('offline');
          return http.Response(
            jsonEncode({'data': _shop, 'total': _shop.length, 'truncated': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final catalogue = ProductCatalogue(ProductsRemoteDataSource(api));

      await catalogue.ensureLoaded();
      fail = true;
      await catalogue.refresh();

      expect(calls, 2);
      expect(catalogue.isSearchable, isTrue);
      expect(catalogue.search('sugar'), isNotEmpty);
    });

    test('parses the light payload into usable line data', () async {
      // The catalogue omits description/specs/variants. What it must carry is
      // everything needed to price an invoice line without a second fetch.
      final b = build(rows: _shop);
      await b.catalogue.ensureLoaded();

      final pen = b.catalogue.search('blue pen').single;
      expect(pen.name, 'Blue Pen');
      expect(pen.sku, 'PEN-BLU');
      expect(pen.unit, 'PCS');
      expect(pen.sellingPrice, 100);
      expect(pen.purchasePrice, 50);
      expect(pen.taxPercent, 5);
    });
  });
}
