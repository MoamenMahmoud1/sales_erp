import '../../../core/storage/app_database.dart';
import '../domain/invoice.dart';
import '../domain/invoice_change.dart';
import '../domain/sale_repository.dart';

class LocalSaleRepository implements SaleRepository {
  @override
  Future<int> createInvoice({
    required int customerId,
    required Map<int, int> products,
  }) async {
    if (products.isEmpty) {
      throw ArgumentError(
        'Invoice must contain at least one product.',
      );
    }

    final database = await AppDatabase.database;

    return database.transaction<int>((txn) async {
      final now =
          DateTime.now().toUtc().toIso8601String();

      final invoiceId = await txn.insert(
        'invoices',
        {
          'customer_id': customerId,
          'created_at': now,
          'updated_at': now,
          'subtotal': 0,
          'coupon_discount': 0,
          'total': 0,
        },
      );

      double subtotal = 0;

      for (final entry in products.entries) {
        final quantity = entry.value;

        if (quantity <= 0) {
          continue;
        }

        final productRows = await txn.query(
          'products',
          columns: ['id', 'price'],
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );

        if (productRows.isEmpty) {
          throw StateError(
            'Product ${entry.key} was not found.',
          );
        }

        final unitPrice =
            (productRows.first['price'] as num)
                .toDouble();

        subtotal += unitPrice * quantity;

        await txn.insert(
          'invoice_items',
          {
            'invoice_id': invoiceId,
            'product_id': entry.key,
            'quantity': quantity,
            'unit_price': unitPrice,
          },
        );
      }

      await txn.update(
        'invoices',
        {
          'subtotal': subtotal,
          'coupon_discount': 0,
          'total': subtotal,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      return invoiceId;
    });
  }

  @override
  Future<List<Map<String, Object?>>>
      getCustomerInvoices(
    int customerId,
  ) async {
    final database = await AppDatabase.database;

    return database.query(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  @override
  Future<Invoice?> getInvoice(
    int invoiceId,
  ) async {
    final database = await AppDatabase.database;

    final invoiceRows = await database.query(
      'invoices',
      where: 'id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );

    if (invoiceRows.isEmpty) {
      return null;
    }

    final itemRows = await database.query(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );

    final products = <int, int>{};

    for (final item in itemRows) {
      products[item['product_id'] as int] =
          item['quantity'] as int;
    }

    return Invoice.fromMap(
      invoiceRows.first,
      products: products,
    );
  }

  @override
  Future<void> updateInvoice({
    required int invoiceId,
    required Map<int, int> products,
  }) async {
    final database = await AppDatabase.database;

    await database.transaction((txn) async {
      final invoiceRows = await txn.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );

      if (invoiceRows.isEmpty) {
        throw StateError(
          'Invoice $invoiceId was not found.',
        );
      }

      final oldItems = await txn.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      final oldProducts = <int, int>{};

      for (final item in oldItems) {
        oldProducts[item['product_id'] as int] =
            item['quantity'] as int;
      }

      final now = DateTime.now().toUtc();

      final changedAt =
          now.toIso8601String();

      final expiresAt = now
          .add(const Duration(hours: 24))
          .toIso8601String();

      final allProductIds = <int>{
        ...oldProducts.keys,
        ...products.keys,
      };

      for (final productId in allProductIds) {
        final oldQuantity =
            oldProducts[productId] ?? 0;

        final newQuantity =
            products[productId] ?? 0;

        if (oldQuantity == newQuantity) {
          continue;
        }

        await txn.insert(
          'invoice_changes',
          {
            'invoice_id': invoiceId,
            'product_id': productId,
            'old_quantity': oldQuantity,
            'new_quantity': newQuantity,
            'changed_at': changedAt,
            'expires_at': expiresAt,
          },
        );
      }

      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      double subtotal = 0;

      for (final entry in products.entries) {
        final quantity = entry.value;

        if (quantity <= 0) {
          continue;
        }

        final productRows = await txn.query(
          'products',
          columns: ['id', 'price'],
          where: 'id = ?',
          whereArgs: [entry.key],
          limit: 1,
        );

        if (productRows.isEmpty) {
          throw StateError(
            'Product ${entry.key} was not found.',
          );
        }

        final unitPrice =
            (productRows.first['price'] as num)
                .toDouble();

        subtotal += unitPrice * quantity;

        await txn.insert(
          'invoice_items',
          {
            'invoice_id': invoiceId,
            'product_id': entry.key,
            'quantity': quantity,
            'unit_price': unitPrice,
          },
        );
      }

      final currentCouponDiscount =
          (invoiceRows.first['coupon_discount']
                  as num?)
              ?.toDouble() ??
          0;

      final total = subtotal - currentCouponDiscount;

      await txn.update(
        'invoices',
        {
          'updated_at': changedAt,
          'subtotal': subtotal,
          'total': total < 0 ? 0 : total,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    });
  }

  @override
  Future<List<InvoiceChange>>
      getRecentInvoiceChanges(
    int invoiceId,
  ) async {
    final database = await AppDatabase.database;

    final now =
        DateTime.now().toUtc().toIso8601String();

    await database.delete(
      'invoice_changes',
      where: '''
        invoice_id = ?
        AND expires_at <= ?
      ''',
      whereArgs: [
        invoiceId,
        now,
      ],
    );

    final rows = await database.query(
      'invoice_changes',
      where: '''
        invoice_id = ?
        AND expires_at > ?
      ''',
      whereArgs: [
        invoiceId,
        now,
      ],
      orderBy: 'changed_at DESC',
    );

    return rows.map((row) {
      return InvoiceChange(
        productId: row['product_id'] as int,
        oldQuantity:
            row['old_quantity'] as int,
        newQuantity:
            row['new_quantity'] as int,
      );
    }).toList();
  }

  @override
  Future<void> deleteInvoice(
    int invoiceId,
  ) async {
    final database = await AppDatabase.database;

    await database.transaction((txn) async {
      await txn.delete(
        'invoice_changes',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      await txn.delete(
        'invoice_coupons',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      await txn.delete(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      await txn.delete(
        'invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
    });
  }
}