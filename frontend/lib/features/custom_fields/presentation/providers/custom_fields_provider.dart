import 'package:flutter/foundation.dart';

import 'package:shopxy/features/custom_fields/data/datasources/custom_fields_remote_data_source.dart';
import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class CustomFieldsProvider extends ChangeNotifier {
  CustomFieldsProvider(this._ds);
  final CustomFieldsRemoteDataSource _ds;

  CustomFieldsTree _tree = const CustomFieldsTree(
    sections: [],
    ungrouped: [],
  );
  List<CustomFieldTemplate> _templates = const [];
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedOnce = false;

  CustomFieldsTree get tree => _tree;
  List<CustomFieldSection> get sections => _tree.sections;
  List<CustomFieldDefinition> get ungrouped => _tree.ungrouped;
  List<CustomFieldTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoadedOnce => _hasLoadedOnce;

  List<CustomFieldDefinition> get allActiveDefinitions {
    return [
      ..._tree.ungrouped.where((d) => d.isActive),
      for (final s in _tree.sections.where((s) => s.isActive))
        ...s.fields.where((d) => d.isActive),
    ];
  }

  void reset() {
    _tree = const CustomFieldsTree(sections: [], ungrouped: []);
    _templates = const [];
    _isLoading = false;
    _error = null;
    _hasLoadedOnce = false;
    notifyListeners();
  }

  Future<void> load({bool activeOnly = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _ds.getTree(activeOnly: activeOnly),
        _ds.listTemplates(),
      ]);
      _tree = results[0] as CustomFieldsTree;
      _templates = results[1] as List<CustomFieldTemplate>;
      _hasLoadedOnce = true;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshTree() async {
    _tree = await _ds.getTree(activeOnly: false);
    notifyListeners();
  }

  Future<void> loadTemplates() async {
    try {
      _templates = await _ds.listTemplates();
      notifyListeners();
    } catch (_) {
    }
  }

  Future<void> applyTemplate(String templateId) async {
    _tree = await _ds.applyTemplate(templateId);
    notifyListeners();
  }

  Future<CustomFieldSection> createSection({
    required String name,
    String? icon,
  }) async {
    final created = await _ds.createSection(name: name, icon: icon);
    await _refreshTree();
    return created;
  }

  Future<void> updateSection(
    String id, {
    String? name,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) async {
    await _ds.updateSection(
      id,
      name: name,
      icon: icon,
      sortOrder: sortOrder,
      isActive: isActive,
    );
    await _refreshTree();
  }

  Future<void> deleteSection(String id) async {
    await _ds.deleteSection(id);
    await _refreshTree();
  }

  Future<void> reorderSections(List<String> orderedIds) async {
    await _ds.reorderSections(orderedIds);
    await _refreshTree();
  }

  Future<CustomFieldDefinition> createDefinition({
    required String name,
    required CustomFieldType type,
    List<String>? options,
    String? unitSuffix,
    String? icon,
    String? sectionId,
  }) async {
    final created = await _ds.createDefinition(
      name: name,
      type: type,
      options: options,
      unitSuffix: unitSuffix,
      icon: icon,
      sectionId: sectionId,
    );
    await _refreshTree();
    return created;
  }

  Future<void> updateDefinition(
    String id, {
    String? name,
    CustomFieldType? type,
    List<String>? options,
    String? unitSuffix,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) async {
    await _ds.updateDefinition(
      id,
      name: name,
      type: type,
      options: options,
      unitSuffix: unitSuffix,
      icon: icon,
      sortOrder: sortOrder,
      isActive: isActive,
    );
    await _refreshTree();
  }

  Future<void> assignToSection(String definitionId, String? sectionId) async {
    await _ds.assignSection(definitionId, sectionId: sectionId);
    await _refreshTree();
  }

  Future<void> deleteDefinition(String id) async {
    await _ds.deleteDefinition(id);
    await _refreshTree();
  }

  Future<void> reorderDefinitions(List<String> orderedIds) async {
    await _ds.reorderDefinitions(orderedIds);
    await _refreshTree();
  }
}
