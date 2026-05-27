import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';

/// Talks to /me/carousels — the merchant-scoped carousel CRUD plus the
/// nested /me/carousels/:cid/slides routes. Tenant scoping is enforced
/// server-side; we just return null on 404 so the provider/page can
/// surface "not found" without throwing.
class CarouselsRemoteDataSource {
  CarouselsRemoteDataSource(this._client);
  final ApiClient _client;

  // ── Carousels ───────────────────────────────────────────────────────

  Future<List<Carousel>> list() async {
    final res = await _client.get('/me/carousels');
    if (res.statusCode != 200) {
      throw Exception('Failed to load carousels: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => Carousel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Carousel?> getOne(int id) async {
    final res = await _client.get('/me/carousels/$id');
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Failed to load carousel: ${res.body}');
    }
    return Carousel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Carousel> create(Map<String, dynamic> body) async {
    final res = await _client.post('/me/carousels', body: body);
    if (res.statusCode != 201) {
      throw Exception('Create carousel failed: ${res.body}');
    }
    return Carousel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Carousel> update(int id, Map<String, dynamic> body) async {
    final res = await _client.patch('/me/carousels/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception('Update carousel failed: ${res.body}');
    }
    return Carousel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    final res = await _client.delete('/me/carousels/$id');
    if (res.statusCode != 204) {
      throw Exception('Delete carousel failed: ${res.body}');
    }
  }

  // ── Slides ──────────────────────────────────────────────────────────

  Future<List<CarouselSlide>> listSlides(int carouselId) async {
    final res = await _client.get('/me/carousels/$carouselId/slides');
    if (res.statusCode != 200) {
      throw Exception('Failed to load slides: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => CarouselSlide.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CarouselSlide?> getSlide(int carouselId, int slideId) async {
    final res = await _client.get('/me/carousels/$carouselId/slides/$slideId');
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw Exception('Failed to load slide: ${res.body}');
    }
    return CarouselSlide.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CarouselSlide> createSlide(
    int carouselId,
    Map<String, dynamic> body,
  ) async {
    final res =
        await _client.post('/me/carousels/$carouselId/slides', body: body);
    if (res.statusCode != 201) {
      throw Exception('Create slide failed: ${res.body}');
    }
    return CarouselSlide.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CarouselSlide> updateSlide(
    int carouselId,
    int slideId,
    Map<String, dynamic> body,
  ) async {
    final res = await _client.patch(
      '/me/carousels/$carouselId/slides/$slideId',
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Update slide failed: ${res.body}');
    }
    return CarouselSlide.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteSlide(int carouselId, int slideId) async {
    final res =
        await _client.delete('/me/carousels/$carouselId/slides/$slideId');
    if (res.statusCode != 204) {
      throw Exception('Delete slide failed: ${res.body}');
    }
  }
}
