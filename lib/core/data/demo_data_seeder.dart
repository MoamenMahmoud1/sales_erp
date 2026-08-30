import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';

import '../storage/app_database.dart';

/// Seeds the local database with believable ERP demo data on first launch so
/// the application looks populated immediately after install.
///
/// Only runs once (guarded by a persisted flag + emptiness checks) and only
/// writes to the local SQLite database.
class DemoDataSeeder {
  static const String _seedFlagKey = 'demo_data_seeded_v1';

  final FlutterSecureStorage _storage;
  final Random _random;

  DemoDataSeeder({FlutterSecureStorage? storage, Random? random})
      : _storage = storage ?? const FlutterSecureStorage(),
        _random = random ?? Random(42);

  /// Seeds demo data if the database is brand new. No-op otherwise.
  Future<void> seedIfNeeded() async {
    bool alreadySeeded = false;
    try {
      alreadySeeded = await _storage.read(key: _seedFlagKey) == 'true';
    } catch (_) {
      alreadySeeded = false;
    }
    if (alreadySeeded) return;

    final database = await AppDatabase.database;
    final hasProducts = await database.query('products', limit: 1);
    final hasCustomers = await database.query('customers', limit: 1);
    if (hasProducts.isNotEmpty || hasCustomers.isNotEmpty) {
      return; // Real data already exists — do not seed over it.
    }

    await _seed(database);
    try {
      await _storage.write(key: _seedFlagKey, value: 'true');
    } catch (_) {
      // Ignore persistence failures; emptiness check still guards re-seeding.
    }
  }

  Future<void> _seed(Database database) async {
    await database.transaction((txn) async {
      final now = DateTime.now();

      const customers = [
        ['Karim El-Sayed', '+20 100 123 4567', '12 El Tahrir St, Cairo', 'cash'],
        ['Sara Hassan', '+20 122 234 5678', '45 Nasr City, Cairo', 'bank_transfer'],
        ['Omar Abdelrahman', '+20 111 987 6543', '8 Zayed City, Giza', 'cash'],
        ['Nour El-Din Markets', '+20 103 456 7890', '22 Suez Rd, Maadi', 'transfer'],
        ['Amr Fathy', '+20 115 321 8901', '60 Alex Rd, Alexandria', 'cash'],
        ['Layla Mansour', '+20 099 765 4321', '4 Corniche, Alexandria', 'transfer'],
        ['Tarek Mahmoud', '+20 101 222 3344', '31 Downtown, Mansoura', 'cash'],
        ['Yassmina Ismail', '+20 107 888 9900', '9 Heliopolis, Cairo', 'transfer'],
      ];

      final customerIds = <int>[];
      for (final c in customers) {
        final id = await txn.insert('customers', {
          'name': c[0],
          'phone': c[1],
          'address': c[2],
          'payment_type': c[3] == 'cash' ? 'cash' : 'bank_transfer',
        });
        customerIds.add(id);
      }

      const products = [
        ['Sunflower Oil 5L', 320.0],
        ['Basmati Rice 10kg', 540.0],
        ['Granulated Sugar 25kg', 720.0],
        ['Instant Coffee 200g', 168.0],
        ['Frozen Chicken 1kg', 145.0],
        ['Pasta 500g', 24.0],
        ['Mineral Water 1.5L', 11.0],
        ['Tea Bags 100 pc', 58.0],
      ];

      final productIds = <int>[];
      for (final p in products) {
        final id = await txn.insert('products', {
          'name': p[0],
          'price': p[1],
          'created_at': _dateTime(now.subtract(const Duration(days: 60))),
          'updated_at': _dateTime(now),
        });
        productIds.add(id);
      }

      // Realistic invoices spread across the last ~30 days with mixed states.
      const totalInvoices = 14;
      for (var i = 0; i < totalInvoices; i++) {
        final daysAgo = 1 + (i * 2 + _random.nextInt(2));
        final created = now
            .subtract(Duration(days: daysAgo))
            .subtract(Duration(hours: _random.nextInt(8)));
        final createdAt = _dateTime(created);

        final customerId = customerIds[_random.nextInt(customerIds.length)];
        final itemCount = 1 + _random.nextInt(3);

        var subtotal = 0.0;
        final chosen = <int>[];
        for (var j = 0; j < itemCount; j++) {
          final pid = productIds[_random.nextInt(productIds.length)];
          if (chosen.contains(pid)) continue;
          chosen.add(pid);
        }
        for (var k = 0; k < chosen.length; k++) {
          final qty = 1 + _random.nextInt(20);
          subtotal += _productPrice(chosen[k], products) * qty;
        }

        final discount = _random.nextDouble() < 0.3
            ? (subtotal * 0.05).roundToDouble()
            : 0.0;
        final total = subtotal - discount;

        final invoiceId = await txn.insert('invoices', {
          'customer_id': customerId,
          'created_at': createdAt,
          'updated_at': createdAt,
          'subtotal': subtotal,
          'coupon_discount': discount,
          'total': total,
        });

        for (final pid in chosen) {
          final qty = 1 + _random.nextInt(20);
          await txn.insert('invoice_items', {
            'invoice_id': invoiceId,
            'product_id': pid,
            'quantity': qty,
            'unit_price': _productPrice(pid, products),
          });
        }

        final roll = _random.nextInt(10);
        final status = roll < 5 ? 'paid' : (roll < 8 ? 'pending' : 'overdue');
        final method = customerId.isEven ? 'cash' : 'transfer';
        await txn.insert('payments', {
          'customer_id': customerId,
          'invoice_id': invoiceId,
          'amount': status == 'paid' ? total : 0,
          'method': method,
          'status': status,
          'reference': status == 'paid' ? null : 'REF-${1000 + invoiceId}',
          'created_at': createdAt,
          'confirmed_at': status == 'paid' ? createdAt : null,
        });
      }
    });
  }

  double _productPrice(int id, List<List<Object>> products) {
    final index = id - 1;
    if (index < 0 || index >= products.length) return 0;
    return products[index][1] as double;
  }

  static String _dateTime(DateTime dt) => dt.toUtc().toIso8601String();
}
