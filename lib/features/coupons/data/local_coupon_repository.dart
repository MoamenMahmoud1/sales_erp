import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/coupon.dart';

class LocalCouponRepository {
  Future<Database> get _database async {
    return AppDatabase.database;
  }

  Future<List<Coupon>> getCoupons() async {
    final database = await _database;

    final rows = await database.query(
      'coupons',
      columns: [
        'id',
        'name',
        'units_per_carton',
        'carton_price',
        'created_at',
        'updated_at',
      ],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(Coupon.fromMap)
        .toList(growable: false);
  }

  Future<Coupon?> getCouponById(
    int couponId,
  ) async {
    if (couponId <= 0) {
      throw ArgumentError(
        'Invalid coupon ID.',
      );
    }

    final database = await _database;

    final rows = await database.query(
      'coupons',
      columns: [
        'id',
        'name',
        'units_per_carton',
        'carton_price',
        'created_at',
        'updated_at',
      ],
      where: 'id = ?',
      whereArgs: [couponId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Coupon.fromMap(rows.first);
  }

  Future<int> addCoupon({
    required String name,
    required int unitsPerCarton,
    required double cartonPrice,
  }) async {
    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'Coupon name is required.',
      );
    }

    if (unitsPerCarton <= 0) {
      throw ArgumentError(
        'Units per carton must be greater than zero.',
      );
    }

    if (cartonPrice <= 0) {
      throw ArgumentError(
        'Carton price must be greater than zero.',
      );
    }

    final database = await _database;

    final now =
        DateTime.now()
            .toUtc()
            .toIso8601String();

    return database.insert(
      'coupons',
      {
        'name': normalizedName,
        'units_per_carton': unitsPerCarton,
        'carton_price': cartonPrice,
        'created_at': now,
        'updated_at': now,
      },
    );
  }

  Future<void> updateCoupon({
    required int id,
    required String name,
    required int unitsPerCarton,
    required double cartonPrice,
  }) async {
    if (id <= 0) {
      throw ArgumentError(
        'Invalid coupon ID.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'Coupon name is required.',
      );
    }

    if (unitsPerCarton <= 0) {
      throw ArgumentError(
        'Units per carton must be greater than zero.',
      );
    }

    if (cartonPrice <= 0) {
      throw ArgumentError(
        'Carton price must be greater than zero.',
      );
    }

    final database = await _database;

    final updatedRows =
        await database.update(
      'coupons',
      {
        'name': normalizedName,
        'units_per_carton':
            unitsPerCarton,
        'carton_price':
            cartonPrice,
        'updated_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    if (updatedRows == 0) {
      throw StateError(
        'Coupon with id $id was not found.',
      );
    }
  }

  Future<void> deleteCoupon(
    int couponId,
  ) async {
    if (couponId <= 0) {
      throw ArgumentError(
        'Invalid coupon ID.',
      );
    }

    final database = await _database;

    try {
      await database.delete(
        'coupons',
        where: 'id = ?',
        whereArgs: [couponId],
      );
    } on DatabaseException catch (error) {
      if (error.toString().contains(
            'FOREIGN KEY constraint failed',
          )) {
        throw StateError(
          'This coupon is already used in an invoice and cannot be deleted.',
        );
      }

      rethrow;
    }
  }

  Future<List<Coupon>> searchCoupons(
    String query,
  ) async {
    final database = await _database;

    final value = query.trim();

    if (value.isEmpty) {
      return getCoupons();
    }

    final rows = await database.query(
      'coupons',
      columns: [
        'id',
        'name',
        'units_per_carton',
        'carton_price',
        'created_at',
        'updated_at',
      ],
      where: 'name LIKE ?',
      whereArgs: ['%$value%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(Coupon.fromMap)
        .toList(growable: false);
  }
}