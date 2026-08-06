import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/shop/data/models/shop.dart';

class ShopRemoteDataSource {
  ShopRemoteDataSource(this._client);
  final ApiClient _client;

  Future<Shop> getMyShop() async {
    final res = await _client.get('/me/shop');
    if (res.statusCode != 200) {
      throw Exception('Failed to load shop: ${res.body}');
    }
    return Shop.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Create the caller's first shop during onboarding (a shopless OWNER names
  /// their shop after signup). POST /me/onboarding/shop → 201 with the shop.
  Future<Shop> createMyShop(String name) async {
    final res = await _client.post(
      '/me/onboarding/shop',
      body: {'name': name.trim()},
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception('Failed to create shop: ${res.body}');
    }
    return Shop.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Patches only the supplied fields. Pass `null` for fields that
  /// should be cleared on the server (matches the PUT contract; the
  /// service interprets explicit-null vs. absent as clear vs. ignore).
  Future<Shop> updateMyShop({
    String? name,
    Object? tagline = _absent,
    Object? logoUrl = _absent,
    Object? bannerUrl = _absent,
    Object? locationCity = _absent,
    Object? locationState = _absent,
    Object? returnPolicy = _absent,
    Object? shippingPolicy = _absent,
    Object? refundPolicy = _absent,
    Object? vacationMode = _absent,
    Object? vacationMessage = _absent,
    Object? returnsEnabled = _absent,
    Object? returnWindowDays = _absent,
    Object? refundMode = _absent,
    Object? returnPolicyNote = _absent,
    Object? cancellationPolicy = _absent,
    Object? operatingHours = _absent,
    Object? pdfTemplateId = _absent,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (!identical(tagline, _absent)) body['tagline'] = tagline;
    if (!identical(logoUrl, _absent)) body['logoUrl'] = logoUrl;
    if (!identical(bannerUrl, _absent)) body['bannerUrl'] = bannerUrl;
    if (!identical(locationCity, _absent)) {
      body['locationCity'] = locationCity;
    }
    if (!identical(locationState, _absent)) {
      body['locationState'] = locationState;
    }
    if (!identical(returnPolicy, _absent)) {
      body['returnPolicy'] = returnPolicy;
    }
    if (!identical(shippingPolicy, _absent)) {
      body['shippingPolicy'] = shippingPolicy;
    }
    if (!identical(refundPolicy, _absent)) {
      body['refundPolicy'] = refundPolicy;
    }
    if (!identical(vacationMode, _absent)) {
      body['vacationMode'] = vacationMode;
    }
    if (!identical(vacationMessage, _absent)) {
      body['vacationMessage'] = vacationMessage;
    }
    if (!identical(returnsEnabled, _absent)) {
      body['returnsEnabled'] = returnsEnabled;
    }
    if (!identical(returnWindowDays, _absent)) {
      body['returnWindowDays'] = returnWindowDays;
    }
    if (!identical(refundMode, _absent)) {
      body['refundMode'] = refundMode;
    }
    if (!identical(returnPolicyNote, _absent)) {
      body['returnPolicyNote'] = returnPolicyNote;
    }
    if (!identical(cancellationPolicy, _absent)) {
      body['cancellationPolicy'] = cancellationPolicy;
    }
    if (!identical(operatingHours, _absent)) {
      body['operatingHours'] = operatingHours;
    }
    if (!identical(pdfTemplateId, _absent)) {
      body['pdfTemplateId'] = pdfTemplateId;
    }
    final res = await _client.put('/me/shop', body: body);
    if (res.statusCode != 200) {
      throw Exception('Failed to save shop: ${res.body}');
    }
    return Shop.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Shop> setPublished(bool isPublished) async {
    final res = await _client.post(
      '/me/shop/publish',
      body: {'isPublished': isPublished},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update publish state: ${res.body}');
    }
    return Shop.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Uploads a single image and returns the **md variant URL**. The
  /// backend generates 3 sizes; the returned `url` is the medium one
  /// (suitable for cards). Banner/logo previews resolve `lg` on demand
  /// by string-replacing the `-md` suffix.
  Future<String> uploadImage(File file) async {
    final streamed = await _client.multipart(
      '/upload',
      makeFile: () => http.MultipartFile.fromPath('file', file.path),
    );
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 201) {
      throw Exception('Upload failed: $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['url'] as String;
  }
}

const _absent = Object();
