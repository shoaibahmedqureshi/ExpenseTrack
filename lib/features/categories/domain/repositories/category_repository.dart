import '../entities/category.dart';

abstract interface class CategoryRepository {
  Future<List<Category>> getAll();
  Future<Category> getById(int id);
  Future<int> insert(Category category);
  Future<void> update(Category category);
  Future<void> delete(int id);
}
