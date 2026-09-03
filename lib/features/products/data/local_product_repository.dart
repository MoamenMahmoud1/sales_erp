import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

class LocalProductRepository implements ProductRepository {
  Future<Database> get _database async => AppDatabase.database;

  String _normalizeCategory(String category) {
    final normalized = category.trim();
    return normalized.isEmpty ? 'General' : normalized;
  }

  @override
  Future<List<Product>> getProducts() async {
    final database = await _database;

    final rows = await database.query(
      'products',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(Product.fromMap).toList(growable: false);
  }

  @override
  Future<int> addProduct({
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
    String category = 'General',
  }) async {
    final normalizedName = name.trim();
    final normalizedCategory = _normalizeCategory(category);
    final normalizedSellingPrice = sellingPrice ?? price;
    final normalizedPurchasePrice = purchasePrice ?? normalizedSellingPrice;

    if (normalizedName.isEmpty) {
      throw ArgumentError('Product name is required.');
    }
    if (normalizedSellingPrice <= 0) {
      throw ArgumentError('Product selling price must be greater than zero.');
    }
    if (normalizedPurchasePrice <= 0) {
      throw ArgumentError('Product purchase price must be greater than zero.');
    }

    final database = await _database;
    final now = DateTime.now().toUtc().toIso8601String();

    return database.insert(
      'products',
      {
        'name': normalizedName,
        'category': normalizedCategory,
        // Legacy column retained as the selling price for existing consumers.
        'price': normalizedSellingPrice,
        'purchase_price': normalizedPurchasePrice,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  @override
  Future<void> updateProduct({
    required int id,
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
    String category = 'General',
  }) async {
    final normalizedName = name.trim();
    final normalizedCategory = _normalizeCategory(category);
    final normalizedSellingPrice = sellingPrice ?? price;
    final normalizedPurchasePrice = purchasePrice ?? normalizedSellingPrice;

    if (normalizedName.isEmpty) {
      throw ArgumentError('Product name is required.');
    }
    if (normalizedSellingPrice <= 0) {
      throw ArgumentError('Product selling price must be greater than zero.');
    }
    if (normalizedPurchasePrice <= 0) {
      throw ArgumentError('Product purchase price must be greater than zero.');
    }

    final database = await _database;

    final updatedRows = await database.update(
      'products',
      {
        'name': normalizedName,
        'category': normalizedCategory,
        // Keep the legacy column synchronized with the selling price.
        'price': normalizedSellingPrice,
        'purchase_price': normalizedPurchasePrice,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updatedRows == 0) {
      throw StateError('Product with id $id was not found.');
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    final database = await _database;

    await database.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
