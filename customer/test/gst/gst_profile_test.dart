import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/features/gst/data/datasources/gst_profile_remote_data_source.dart';
import 'package:shopxy_customer/features/gst/domain/entities/gst_profile.dart';
import 'package:shopxy_customer/features/gst/presentation/providers/gst_profile_provider.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';

class _FakeDs implements GstProfileRemoteDataSource {
  _FakeDs({this.initial = const GstProfile.empty(), this.rejectWith});

  final GstProfile initial;
  final GstProfileRejected? rejectWith;
  int saveCalls = 0;
  String? lastGstin;
  GstProfile _saved = const GstProfile.empty();

  @override
  Future<GstProfile> fetch() async => initial;

  @override
  Future<GstProfile> save({String? gstin, String? legalName}) async {
    saveCalls++;
    lastGstin = gstin;
    if (rejectWith != null) throw rejectWith!;
    _saved = GstProfile(gstin: gstin, legalName: legalName);
    return _saved;
  }
}

void main() {
  group('GstProfile', () {
    test('is complete only when both the GSTIN and the legal name are set', () {
      expect(const GstProfile.empty().isComplete, isFalse);
      expect(const GstProfile(gstin: '19AAACI1681G1ZM').isComplete, isFalse);
      expect(const GstProfile(legalName: 'Indus Trading').isComplete, isFalse);
      expect(
        const GstProfile(
          gstin: '19AAACI1681G1ZM',
          legalName: 'Indus Trading',
        ).isComplete,
        isTrue,
      );
    });

    test('parses the server payload', () {
      final p = GstProfile.fromJson({
        'gstin': '19AAACI1681G1ZM',
        'legalName': 'Indus Trading Co Pvt Ltd',
      });
      expect(p.gstin, '19AAACI1681G1ZM');
      expect(p.legalName, 'Indus Trading Co Pvt Ltd');
      expect(p.isComplete, isTrue);
    });
  });

  group('GstProfileProvider', () {
    test('load populates the profile and unlocks claiming', () async {
      final provider = GstProfileProvider(
        _FakeDs(
          initial: const GstProfile(
            gstin: '19AAACI1681G1ZM',
            legalName: 'Indus Trading Co Pvt Ltd',
          ),
        ),
      );
      expect(provider.canClaimGst, isFalse);
      await provider.load();
      expect(provider.isLoaded, isTrue);
      expect(provider.canClaimGst, isTrue);
    });

    test('save returns null on success and keeps the new profile', () async {
      final provider = GstProfileProvider(_FakeDs());
      final failure = await provider.save(
        gstin: '19AAACI1681G1ZM',
        legalName: 'Indus Trading Co Pvt Ltd',
      );
      expect(failure, isNull);
      expect(provider.profile.gstin, '19AAACI1681G1ZM');
      expect(provider.canClaimGst, isTrue);
    });

    test('a rejected GSTIN surfaces the server message, not a retry', () async {
      final provider = GstProfileProvider(
        _FakeDs(
          rejectWith: const GstProfileRejected(
            message: 'That GSTIN is not valid.',
            code: 'INVALID_GSTIN',
          ),
        ),
      );
      final failure = await provider.save(
        gstin: '19AAACI1681G1ZX',
        legalName: 'Indus Trading Co Pvt Ltd',
      );
      expect(failure, 'That GSTIN is not valid.');
      expect(provider.canClaimGst, isFalse);
    });

    test('clearing sends a null GSTIN and drops the claim', () async {
      final ds = _FakeDs(
        initial: const GstProfile(
          gstin: '19AAACI1681G1ZM',
          legalName: 'Indus Trading Co Pvt Ltd',
        ),
      );
      final provider = GstProfileProvider(ds);
      await provider.load();
      expect(provider.canClaimGst, isTrue);

      final failure = await provider.save(gstin: null);
      expect(failure, isNull);
      expect(ds.lastGstin, isNull);
      expect(provider.canClaimGst, isFalse);
    });

    test('sign-out clears the profile so the next user starts B2C', () async {
      final provider = GstProfileProvider(
        _FakeDs(
          initial: const GstProfile(
            gstin: '19AAACI1681G1ZM',
            legalName: 'Indus Trading Co Pvt Ltd',
          ),
        ),
      );
      await provider.load();
      provider.clear();
      expect(provider.canClaimGst, isFalse);
      expect(provider.isLoaded, isFalse);
    });
  });

  group('CatalogProduct.shopGstRegistered', () {
    test('reads the seller GST flag off the shop payload', () {
      final product = CatalogProduct.fromJson({
        'id': '1',
        'name': 'Widget',
        'sku': 'W-1',
        'unit': 'PCS',
        'sellingPrice': 100,
        'mrp': 120,
        'taxPercent': 18,
        'stockQuantity': 5,
        'shop': {'id': '9', 'name': 'Sharma Electronics', 'gstRegistered': true},
      });
      expect(product.shopGstRegistered, isTrue);
    });

    test('defaults to false when the payload omits it', () {
      final product = CatalogProduct.fromJson({
        'id': '1',
        'name': 'Widget',
        'sku': 'W-1',
        'unit': 'PCS',
        'sellingPrice': 100,
        'mrp': 120,
        'taxPercent': 18,
        'stockQuantity': 5,
        'shop': {'id': '9', 'name': 'Sharma Electronics'},
      });
      expect(product.shopGstRegistered, isFalse);
    });
  });
}
