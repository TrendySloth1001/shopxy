import 'package:flutter/foundation.dart';
import 'package:shopxy/features/carousel/data/datasources/carousels_remote_data_source.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';

/// State for the merchant's carousels list + the currently-open
/// carousel's slides. The page-level state (which carousel is open,
/// which slide is being edited) stays in widgets — this provider only
/// holds the cached server lists so navigation away + back doesn't
/// re-fetch unless the merchant pulled to refresh.
class CarouselsProvider extends ChangeNotifier {
  CarouselsProvider(this._ds);
  final CarouselsRemoteDataSource _ds;

  final List<Carousel> _carousels = [];
  /// Per-carousel cache of slides keyed by carouselId. Loaded lazily
  /// when the editor opens; cleared on `reset()` and on parent delete.
  final Map<int, List<CarouselSlide>> _slidesByCarousel = {};

  bool _loadingCarousels = false;
  /// Tracks which carousel ids are currently fetching slides so the
  /// page can show a spinner without us toggling a boolean for the
  /// merchant's last-opened carousel only.
  final Set<int> _loadingSlides = <int>{};
  String? _error;

  List<Carousel> get carousels {
    final out = List<Carousel>.from(_carousels);
    out.sort((a, b) {
      final p = a.placement.index.compareTo(b.placement.index);
      if (p != 0) return p;
      final s = a.sortOrder.compareTo(b.sortOrder);
      if (s != 0) return s;
      return b.id.compareTo(a.id); // newer first within ties
    });
    return List.unmodifiable(out);
  }

  bool get isLoading => _loadingCarousels;
  bool isLoadingSlides(int carouselId) => _loadingSlides.contains(carouselId);
  String? get error => _error;

  List<CarouselSlide> slidesFor(int carouselId) =>
      List.unmodifiable(_slidesByCarousel[carouselId] ?? const []);

  /// Clear all in-memory state. Wired via AuthProvider.registerOnClear
  /// in main.dart so the next session doesn't see the previous user's
  /// carousels flash on screen for a frame.
  void reset() {
    _carousels.clear();
    _slidesByCarousel.clear();
    _loadingSlides.clear();
    _loadingCarousels = false;
    _error = null;
    notifyListeners();
  }

  // ── Carousels ───────────────────────────────────────────────────────

  Future<void> load() async {
    _loadingCarousels = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _ds.list();
      _carousels
        ..clear()
        ..addAll(rows);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingCarousels = false;
      notifyListeners();
    }
  }

  Future<Carousel?> create(Map<String, dynamic> body) async {
    try {
      final created = await _ds.create(body);
      _carousels.add(created);
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Carousel?> update(int id, Map<String, dynamic> body) async {
    try {
      final updated = await _ds.update(id, body);
      final i = _carousels.indexWhere((c) => c.id == id);
      if (i >= 0) _carousels[i] = updated;
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _ds.delete(id);
      _carousels.removeWhere((c) => c.id == id);
      _slidesByCarousel.remove(id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Slides ──────────────────────────────────────────────────────────

  Future<void> loadSlides(int carouselId) async {
    _loadingSlides.add(carouselId);
    _error = null;
    notifyListeners();
    try {
      final rows = await _ds.listSlides(carouselId);
      _slidesByCarousel[carouselId] = rows;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingSlides.remove(carouselId);
      notifyListeners();
    }
  }

  Future<CarouselSlide?> createSlide(
    int carouselId,
    Map<String, dynamic> body,
  ) async {
    try {
      final created = await _ds.createSlide(carouselId, body);
      final list = _slidesByCarousel[carouselId] ?? <CarouselSlide>[];
      _slidesByCarousel[carouselId] = [...list, created];
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<CarouselSlide?> updateSlide(
    int carouselId,
    int slideId,
    Map<String, dynamic> body,
  ) async {
    try {
      final updated = await _ds.updateSlide(carouselId, slideId, body);
      final list = _slidesByCarousel[carouselId];
      if (list != null) {
        final i = list.indexWhere((s) => s.id == slideId);
        if (i >= 0) {
          _slidesByCarousel[carouselId] = [
            ...list.sublist(0, i),
            updated,
            ...list.sublist(i + 1),
          ];
        }
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteSlide(int carouselId, int slideId) async {
    try {
      await _ds.deleteSlide(carouselId, slideId);
      final list = _slidesByCarousel[carouselId];
      if (list != null) {
        _slidesByCarousel[carouselId] =
            list.where((s) => s.id != slideId).toList();
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
