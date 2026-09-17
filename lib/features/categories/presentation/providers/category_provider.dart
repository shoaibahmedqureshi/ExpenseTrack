import 'package:flutter/foundation.dart';
import '../../domain/entities/category.dart' as cat;
import '../../domain/repositories/category_repository.dart';

class CategoryProvider extends ChangeNotifier {
  CategoryProvider(this._repository);

  final CategoryRepository _repository;

  List<cat.Category> _categories = [];
  bool _isLoading = false;

  List<cat.Category> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();
    _categories = await _repository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  /// Drops the in-memory list on sign-out, before any other account signs
  /// in on this device — every local query is scoped by uid now (see
  /// CategoryRepositoryImpl), so a fresh loadAll() would already return the
  /// right thing regardless, but without this a screen that reads
  /// categories before that first reload finishes could still flash
  /// whichever account was previously signed in for a moment.
  void clear() {
    _categories = [];
    notifyListeners();
  }
}
