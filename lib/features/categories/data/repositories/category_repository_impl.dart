import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl(this._db);

  final Database _db;

  @override
  Future<List<Category>> getAll() async {
    final rows = await _db.query(AppConstants.categoriesTable);
    return rows.map(CategoryModel.fromMap).toList();
  }

  @override
  Future<Category> getById(int id) async {
    final rows = await _db.query(
      AppConstants.categoriesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    return CategoryModel.fromMap(rows.first);
  }

  @override
  Future<int> insert(Category category) =>
      _db.insert(AppConstants.categoriesTable,
          CategoryModel.fromEntity(category).toMap());

  @override
  Future<void> update(Category category) async {
    await _db.update(
      AppConstants.categoriesTable,
      CategoryModel.fromEntity(category).toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(
      AppConstants.categoriesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
