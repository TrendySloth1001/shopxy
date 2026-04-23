import 'package:flutter/material.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/data/models/party_dto.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';

class PartiesProvider extends ChangeNotifier {
  PartiesProvider(this._ds);
  final PartiesRemoteDataSource _ds;

  List<Party> _parties = [];
  bool _isLoading = false;
  String? _error;
  String _search = '';

  List<Party> get parties => _parties;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get search => _search;

  Future<void> loadParties({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (refresh) notifyListeners();
    try {
      _parties = await _ds.getParties(search: _search.isNotEmpty ? _search : null);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    _search = value;
    loadParties(refresh: true);
  }

  Future<Party> createParty({
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
  }) async {
    final party = await _ds.createParty(
      name: name,
      contactName: contactName,
      phone: phone,
      email: email,
      address: address,
      gstin: gstin,
    );
    _parties = [party, ..._parties];
    notifyListeners();
    return party;
  }

  Future<Party> updateParty(int id, {
    String? name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
    bool? isActive,
  }) async {
    final party = await _ds.updateParty(
      id,
      PartyDto.toUpdateJson(
        name: name,
        contactName: contactName,
        phone: phone,
        email: email,
        address: address,
        gstin: gstin,
        isActive: isActive,
      ),
    );
    _parties = _parties.map((p) => p.id == id ? party : p).toList();
    notifyListeners();
    return party;
  }

  Future<void> deleteParty(int id) async {
    await _ds.deleteParty(id);
    _parties = _parties.where((p) => p.id != id).toList();
    notifyListeners();
  }
}
