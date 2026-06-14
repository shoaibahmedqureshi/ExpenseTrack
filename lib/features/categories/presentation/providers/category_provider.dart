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
}
