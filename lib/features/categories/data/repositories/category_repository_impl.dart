import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  // uidOverride is a testing seam only — see ExpenseLocalDatasource.
  CategoryRepositoryImpl(this._db, {String? uidOverride})
      : _uidOverride = uidOverride;

  final Database _db;
  final String? _uidOverride;

  // See ExpenseLocalDatasource._uid — same reasoning: read live, not
  // captured at construction, since this repo outlives any single session.
  String? get _uid =>
      _uidOverride ?? Supabase.instance.client.auth.currentUser?.id;

  @override
  Future<List<Category>> getAll() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _db.query(
      AppConstants.categoriesTable,
      where: 'user_id = ?',
      whereArgs: [uid],
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  @override
  Future<Category> getById(int id) async {
    final rows = await _db.query(
      AppConstants.categoriesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _uid],
    );
    return CategoryModel.fromMap(rows.first);
  }

  @override
  Future<int> insert(Category category) => _db.insert(
      AppConstants.categoriesTable,
      {...CategoryModel.fromEntity(category).toMap(), 'user_id': _uid});

  @override
  Future<void> update(Category category) async {
    await _db.update(
      AppConstants.categoriesTable,
      CategoryModel.fromEntity(category).toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [category.id, _uid],
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(
      AppConstants.categoriesTable,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _uid],
    );
  }
}
