import 'package:sales_erp/core/storage/app_database.dart';
import 'package:sales_erp/features/coupons/domain/entities/coupon.dart';
import 'package:sqflite/sqflite.dart';

class LocalCouponRepository {
  Future<Database> get _database => AppDatabase.database;

  Future<List<Coupon>> getCoupons() async {
    final rows = await (await _database).query(
      'coupons',
      orderBy: 'name ASC',
    );
    return rows.map((row) {
      return Coupon.fromMap({
        ...row,
        'units_per_carton': row['pieces_per_coupon'],
        'carton_price': row['unit_price'],
      });
    }).toList(growable: false);
  }

  Future<Coupon?> getCouponById(int couponId) async {
    final rows = await (await _database).query(
      'coupons',
      where: 'id = ?',
      whereArgs: [couponId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Coupon.fromMap({
      ...row,
      'units_per_carton': row['pieces_per_coupon'],
      'carton_price': row['unit_price'],
    });
  }

  Future<int> addCoupon({
    required String name,
    required int unitsPerCarton,
    required double cartonPrice,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return (await _database).insert('coupons', {
      'name': name,
      'pieces_per_coupon': unitsPerCarton,
      'unit_price': cartonPrice,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateCoupon({
    required int id,
    required String name,
    required int unitsPerCarton,
    required double cartonPrice,
  }) async {
    final updated = await (await _database).update(
      'coupons',
      {
        'name': name,
        'pieces_per_coupon': unitsPerCarton,
        'unit_price': cartonPrice,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw StateError('Coupon not found.');
  }

  Future<void> deleteCoupon(int couponId) async {
    await (await _database).delete(
      'coupons',
      where: 'id = ?',
      whereArgs: [couponId],
    );
  }

  Future<List<Coupon>> searchCoupons(String query) async {
    final value = query.trim();
    if (value.isEmpty) return getCoupons();
    final rows = await (await _database).query(
      'coupons',
      where: 'name LIKE ?',
      whereArgs: ['%$value%'],
      orderBy: 'name ASC',
    );
    return rows.map((row) {
      return Coupon.fromMap({
        ...row,
        'units_per_carton': row['pieces_per_coupon'],
        'carton_price': row['unit_price'],
      });
    }).toList(growable: false);
  }
}
