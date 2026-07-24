import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/custom_fields/data/models/custom_field_dto.dart';
import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';

/// Throw a clean error message when the server returns a non-2xx
/// status. Without this, the data source happily casts the error map
/// (`{error: "..."}`) to a `List` and the user sees a confusing
/// "_Map is not a subtype of List" cast crash instead of the actual
/// backend error.
void _expectOk(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) return;
  try {
    final body = jsonDecode(response.body);
    if (body is Map && body['error'] is String) {
      throw Exception(body['error']);
    }
  } catch (_) {
    // fall through to the generic message
  }
  throw Exception(
    'Request failed (${response.statusCode}): ${response.body}',
  );
}

class CustomFieldsRemoteDataSource {
  const CustomFieldsRemoteDataSource(this._client);
  final ApiClient _client;

  // ── Tree + templates ───────────────────────────────────────────────

  Future<CustomFieldsTree> getTree({bool activeOnly = true}) async {
    final response = await _client.get(
      '/custom-fields/tree',
      queryParameters: {'active': activeOnly.toString()},
    );
    _expectOk(response);
    return CustomFieldsTreeDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<CustomFieldTemplate>> listTemplates() async {
    final response = await _client.get('/custom-fields/templates');
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => CustomFieldTemplateDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomFieldsTree> applyTemplate(String templateId) async {
    final response = await _client.post(
      '/custom-fields/templates/apply',
      body: {'templateId': templateId},
    );
    _expectOk(response);
    return CustomFieldsTreeDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // ── Sections ───────────────────────────────────────────────────────

  Future<List<CustomFieldSection>> listSections({
    bool activeOnly = true,
  }) async {
    final response = await _client.get(
      '/custom-fields/sections',
      queryParameters: {'active': activeOnly.toString()},
    );
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => CustomFieldSectionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomFieldSection> createSection({
    required String name,
    String? icon,
    int? sortOrder,
  }) async {
    final response = await _client.post(
      '/custom-fields/sections',
      body: CustomFieldSectionDto.toCreateJson(
        name: name,
        icon: icon,
        sortOrder: sortOrder,
      ),
    );
    _expectOk(response);
    return CustomFieldSectionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CustomFieldSection> updateSection(
    String id, {
    String? name,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _client.patch(
      '/custom-fields/sections/$id',
      body: CustomFieldSectionDto.toUpdateJson(
        name: name,
        icon: icon,
        sortOrder: sortOrder,
        isActive: isActive,
      ),
    );
    _expectOk(response);
    return CustomFieldSectionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteSection(String id) async {
    await _client.delete('/custom-fields/sections/$id');
  }

  Future<List<CustomFieldSection>> reorderSections(List<String> orderedIds) async {
    final response = await _client.patch(
      '/custom-fields/sections/reorder',
      body: {'orderedIds': orderedIds},
    );
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => CustomFieldSectionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Definitions ────────────────────────────────────────────────────

  Future<List<CustomFieldDefinition>> listDefinitions({
    bool activeOnly = true,
  }) async {
    final response = await _client.get(
      '/custom-fields',
      queryParameters: {'active': activeOnly.toString()},
    );
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) =>
            CustomFieldDefinitionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomFieldDefinition> createDefinition({
    required String name,
    required CustomFieldType type,
    List<String>? options,
    String? unitSuffix,
    String? icon,
    String? sectionId,
    int? sortOrder,
  }) async {
    final response = await _client.post(
      '/custom-fields',
      body: CustomFieldDefinitionDto.toCreateJson(
        name: name,
        type: type,
        options: options,
        unitSuffix: unitSuffix,
        icon: icon,
        sectionId: sectionId,
        sortOrder: sortOrder,
      ),
    );
    _expectOk(response);
    return CustomFieldDefinitionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CustomFieldDefinition> updateDefinition(
    String id, {
    String? name,
    CustomFieldType? type,
    List<String>? options,
    String? unitSuffix,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) async {
    final response = await _client.patch(
      '/custom-fields/$id',
      body: CustomFieldDefinitionDto.toUpdateJson(
        name: name,
        type: type,
        options: options,
        unitSuffix: unitSuffix,
        icon: icon,
        sortOrder: sortOrder,
        isActive: isActive,
      ),
    );
    _expectOk(response);
    return CustomFieldDefinitionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Move a field between sections (or pass `sectionId: null` to
  /// detach). Kept separate from [updateDefinition] because `null`
  /// here is the meaningful "ungroup" signal, while in
  /// [updateDefinition] null fields are stripped from the payload.
  Future<CustomFieldDefinition> assignSection(
    String definitionId, {
    required String? sectionId,
  }) async {
    final response = await _client.patch(
      '/custom-fields/$definitionId',
      body: CustomFieldDefinitionDto.toAssignSectionJson(sectionId: sectionId),
    );
    _expectOk(response);
    return CustomFieldDefinitionDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> deleteDefinition(String id) async {
    await _client.delete('/custom-fields/$id');
  }

  Future<List<CustomFieldDefinition>> reorderDefinitions(
    List<String> orderedIds,
  ) async {
    final response = await _client.patch(
      '/custom-fields/reorder',
      body: {'orderedIds': orderedIds},
    );
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) =>
            CustomFieldDefinitionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Per-product values ─────────────────────────────────────────────

  Future<List<ProductCustomFieldValue>> listValuesForProduct(
    String productId,
  ) async {
    final response = await _client.get('/products/$productId/custom-fields');
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) =>
            ProductCustomFieldValueDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Bulk-replace values for a product in one call. Empty-string
  /// values clear that field's row.
  Future<List<ProductCustomFieldValue>> bulkSetValuesForProduct(
    String productId,
    List<({String definitionId, String value})> entries,
  ) async {
    final response = await _client.put(
      '/products/$productId/custom-fields',
      body: {
        'values': entries
            .map((e) => {
                  'definitionId': e.definitionId,
                  'value': e.value,
                })
            .toList(),
      },
    );
    _expectOk(response);
    final data = jsonDecode(response.body) as List;
    return data
        .map((e) =>
            ProductCustomFieldValueDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
