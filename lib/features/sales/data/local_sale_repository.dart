import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../../customers/domain/payment_method.dart';
import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../domain/entities/invoice_revision.dart';
import '../domain/entities/invoice_revision_item.dart';

/// Local persistence for normal customer sales.
///
/// Invoice mutations and their immutable revision snapshots are persisted in
/// the same SQLite transaction. The UI never writes directly to SQLite.
class LocalSaleRepository {
  final LocalProductRepository _productRepository = LocalProductRepository();

  Future<Database> get _database => AppDatabase.database;

  Future<List<Map<String, Object?>>> getInvoices() async {
    final database = await _database;
    return database.rawQuery('''
      SELECT
        i.id,
        i.customer_id,
        c.name AS customer_name,
        i.created_at,
        i.updated_at,
        i.subtotal,
        i.coupon_discount,
        i.total,
        COALESCE((
          SELECT SUM(p.amount)
          FROM payments p
          WHERE p.invoice_id = i.id AND p.status = 'paid'
        ), 0) AS paid_amount,
        CASE
          WHEN COALESCE((
            SELECT SUM(p.amount)
            FROM payments p
            WHERE p.invoice_id = i.id AND p.status = 'paid'
          ), 0) >= i.total THEN 'paid'
          WHEN EXISTS (
            SELECT 1 FROM payments p
            WHERE p.invoice_id = i.id AND p.status = 'pending'
          ) THEN 'pending'
          ELSE 'unpaid'
        END AS payment_status
      FROM invoices i
      INNER JOIN customers c ON c.id = i.customer_id
      ORDER BY i.created_at DESC
    ''');
  }

  Future<List<Map<String, Object?>>> getCustomerInvoices(int customerId) async {
    final database = await _database;
    return database.rawQuery('''
      SELECT
        i.id,
        i.customer_id,
        c.name AS customer_name,
        i.created_at,
        i.updated_at,
        i.subtotal,
        i.coupon_discount,
        i.total,
        COALESCE((
          SELECT SUM(p.amount)
          FROM payments p
          WHERE p.invoice_id = i.id AND p.status = 'paid'
        ), 0) AS paid_amount,
        CASE
          WHEN COALESCE((
            SELECT SUM(p.amount)
            FROM payments p
            WHERE p.invoice_id = i.id AND p.status = 'paid'
          ), 0) >= i.total THEN 'paid'
          WHEN EXISTS (
            SELECT 1 FROM payments p
            WHERE p.invoice_id = i.id AND p.status = 'pending'
          ) THEN 'pending'
          ELSE 'unpaid'
        END AS payment_status
      FROM invoices i
      INNER JOIN customers c ON c.id = i.customer_id
      WHERE i.customer_id = ?
      ORDER BY i.created_at DESC
    ''', [customerId]);
  }

  Future<Map<String, Object?>?> getInvoiceWithItems(int invoiceId) async {
    final database = await _database;
    final headers = await database.rawQuery('''
      SELECT
        i.id,
        i.customer_id,
        c.name AS customer_name,
        c.phone AS customer_phone,
        i.created_at,
        i.updated_at,
        i.subtotal,
        i.coupon_discount,
        i.total,
        COALESCE((
          SELECT SUM(p.amount)
          FROM payments p
          WHERE p.invoice_id = i.id AND p.status = 'paid'
        ), 0) AS paid_amount,
        CASE
          WHEN COALESCE((
            SELECT SUM(p.amount)
            FROM payments p
            WHERE p.invoice_id = i.id AND p.status = 'paid'
          ), 0) >= i.total THEN 'paid'
          WHEN EXISTS (
            SELECT 1 FROM payments p
            WHERE p.invoice_id = i.id AND p.status = 'pending'
          ) THEN 'pending'
          ELSE 'unpaid'
        END AS payment_status,
        (
          SELECT p.method
          FROM payments p
          WHERE p.invoice_id = i.id
          ORDER BY p.id DESC
          LIMIT 1
        ) AS payment_method
      FROM invoices i
      INNER JOIN customers c ON c.id = i.customer_id
      WHERE i.id = ?
      LIMIT 1
    ''', [invoiceId]);

    if (headers.isEmpty) return null;
    final items = await database.rawQuery('''
      SELECT ii.product_id, pr.name AS product_name,
             ii.quantity, ii.unit_price
      FROM invoice_items ii
      INNER JOIN products pr ON pr.id = ii.product_id
      WHERE ii.invoice_id = ?
      ORDER BY ii.id ASC
    ''', [invoiceId]);

    return {...headers.first, 'items': items};
  }

  Future<List<InvoiceRevision>> getInvoiceRevisions(int invoiceId) async {
    final database = await _database;
    final revisionRows = await database.query(
      'invoice_revisions',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'revision_number ASC',
    );
    if (revisionRows.isEmpty) return const [];

    final ids = revisionRows.map((row) => row['id'] as int).toList(growable: false);
    final placeholders = List.filled(ids.length, '?').join(',');
    final itemRows = await database.query(
      'invoice_revision_items',
      where: 'revision_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'id ASC',
    );
    final itemsByRevision = <int, List<InvoiceRevisionItem>>{};
    for (final row in itemRows) {
      final revisionId = row['revision_id'] as int;
      (itemsByRevision[revisionId] ??= <InvoiceRevisionItem>[]).add(
        InvoiceRevisionItem(
          productId: (row['product_id'] as num).toInt(),
          productName: row['product_name'] as String,
          quantity: (row['quantity'] as num).toInt(),
          unitPrice: (row['unit_price'] as num).toDouble(),
        ),
      );
    }

    return revisionRows
        .map(
          (row) => InvoiceRevision(
            id: row['id'] as int,
            invoiceId: row['invoice_id'] as int,
            revisionNumber: row['revision_number'] as int,
            createdAt: DateTime.parse(row['created_at'] as String),
            customerId: row['customer_id'] as int,
            customerName: row['customer_name'] as String,
            subtotal: (row['subtotal'] as num).toDouble(),
            discount: (row['coupon_discount'] as num).toDouble(),
            total: (row['total'] as num).toDouble(),
            items: List.unmodifiable(itemsByRevision[row['id'] as int] ?? const []),
          ),
        )
        .toList(growable: false);
  }

  Future<int> createInvoice({
    required int customerId,
    required Map<int, int> products,
    required PaymentMethod paymentMethod,
    double couponDiscount = 0,
  }) async {
    if (products.isEmpty) throw ArgumentError('Invoice is empty.');
    final available = await _productRepository.getProducts();
    final byId = {for (final product in available) product.id: product};
    final calculation = _calculate(products, byId, couponDiscount);
    final database = await _database;

    return database.transaction((transaction) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final customer = await transaction.query(
        'customers',
        columns: ['id', 'name'],
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customer.isEmpty) throw StateError('Customer not found.');

      final invoiceId = await transaction.insert('invoices', {
        'customer_id': customerId,
        'created_at': now,
        'updated_at': now,
        'subtotal': calculation.subtotal,
        'coupon_discount': calculation.discount,
        'total': calculation.total,
      });

      await _replaceItems(transaction, invoiceId, products, byId);
      await transaction.insert('payments', {
        'customer_id': customerId,
        'invoice_id': invoiceId,
        'amount': 0,
        'method': paymentMethod.value,
        'status': 'pending',
        'created_at': now,
      });
      await _insertRevision(
        transaction,
        invoiceId: invoiceId,
        revisionNumber: 1,
        customerId: customerId,
        customerName: customer.first['name'] as String,
        subtotal: calculation.subtotal,
        discount: calculation.discount,
        total: calculation.total,
        products: products,
        byId: byId,
        createdAt: now,
      );
      return invoiceId;
    });
  }

  Future<void> updateInvoice({
    required int invoiceId,
    required int customerId,
    required Map<int, int> products,
    required PaymentMethod paymentMethod,
    double couponDiscount = 0,
  }) async {
    if (invoiceId <= 0) throw ArgumentError('Invalid invoice id.');
    if (products.isEmpty) throw ArgumentError('Invoice is empty.');
    final available = await _productRepository.getProducts();
    final byId = {for (final product in available) product.id: product};
    final calculation = _calculate(products, byId, couponDiscount);
    final database = await _database;

    await database.transaction((transaction) async {
      final current = await transaction.query(
        'invoices',
        columns: ['id', 'customer_id'],
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (current.isEmpty) throw StateError('Invoice not found.');
      if (current.first['customer_id'] != customerId) {
        throw StateError('Invoice does not belong to this customer.');
      }

      final paidRows = await transaction.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS paid
        FROM payments
        WHERE invoice_id = ? AND status = 'paid'
      ''', [invoiceId]);
      final paid = (paidRows.first['paid'] as num?)?.toDouble() ?? 0;
      if (calculation.total < paid) {
        throw StateError('Invoice total cannot be lower than money already paid.');
      }

      final customer = await transaction.query(
        'customers',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customer.isEmpty) throw StateError('Customer not found.');

      final now = DateTime.now().toUtc().toIso8601String();
      await transaction.update(
        'invoices',
        {
          'subtotal': calculation.subtotal,
          'coupon_discount': calculation.discount,
          'total': calculation.total,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      await _replaceItems(transaction, invoiceId, products, byId);

      // Keep payment history. Only maintain a pending placeholder when no
      // payment record exists so the legacy payment screens still have a
      // method to display/edit.
      final paymentRows = await transaction.query(
        'payments',
        columns: ['id'],
        where: 'invoice_id = ?',
        limit: 1,
      );
      if (paymentRows.isEmpty) {
        await transaction.insert('payments', {
          'customer_id': customerId,
          'invoice_id': invoiceId,
          'amount': 0,
          'method': paymentMethod.value,
          'status': 'pending',
          'created_at': now,
        });
      }

      final latest = await transaction.query(
        'invoice_revisions',
        columns: ['revision_number'],
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
        orderBy: 'revision_number DESC',
        limit: 1,
      );
      final nextRevision = latest.isEmpty
          ? 1
          : (latest.first['revision_number'] as int) + 1;
      await _insertRevision(
        transaction,
        invoiceId: invoiceId,
        revisionNumber: nextRevision,
        customerId: customerId,
        customerName: customer.first['name'] as String,
        subtotal: calculation.subtotal,
        discount: calculation.discount,
        total: calculation.total,
        products: products,
        byId: byId,
        createdAt: now,
      );
    });
  }

  Future<void> deleteInvoice(int invoiceId) async {
    final database = await _database;
    final paidRows = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS paid
      FROM payments
      WHERE invoice_id = ? AND status = 'paid'
    ''', [invoiceId]);
    final paid = (paidRows.first['paid'] as num?)?.toDouble() ?? 0;
    if (paid > 0) {
      throw StateError('Paid invoices cannot be deleted; preserve their history.');
    }
    await database.delete('invoices', where: 'id = ?', whereArgs: [invoiceId]);
  }

  _InvoiceCalculation _calculate(
    Map<int, int> products,
    Map<int, Product> byId,
    double couponDiscount,
  ) {
    var subtotal = 0.0;
    for (final entry in products.entries) {
      final product = byId[entry.key];
      if (product == null || entry.value <= 0) {
        throw ArgumentError('Invalid invoice product.');
      }
      subtotal += product.price * entry.value;
    }
    if (!couponDiscount.isFinite || couponDiscount < 0) {
      throw ArgumentError('Invalid discount.');
    }
    final discount = couponDiscount.clamp(0, subtotal).toDouble();
    return _InvoiceCalculation(
      subtotal: subtotal,
      discount: discount,
      total: subtotal - discount,
    );
  }

  Future<void> _replaceItems(
    Transaction transaction,
    int invoiceId,
    Map<int, int> products,
    Map<int, Product> byId,
  ) async {
    await transaction.delete(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
    );
    for (final entry in products.entries) {
      await transaction.insert('invoice_items', {
        'invoice_id': invoiceId,
        'product_id': entry.key,
        'quantity': entry.value,
        'unit_price': byId[entry.key]!.price,
      });
    }
  }

  Future<void> _insertRevision(
    Transaction transaction, {
    required int invoiceId,
    required int revisionNumber,
    required int customerId,
    required String customerName,
    required double subtotal,
    required double discount,
    required double total,
    required Map<int, int> products,
    required Map<int, Product> byId,
    required String createdAt,
  }) async {
    final revisionId = await transaction.insert('invoice_revisions', {
      'invoice_id': invoiceId,
      'revision_number': revisionNumber,
      'created_at': createdAt,
      'customer_id': customerId,
      'customer_name': customerName,
      'subtotal': subtotal,
      'coupon_discount': discount,
      'total': total,
    });
    for (final entry in products.entries) {
      await transaction.insert('invoice_revision_items', {
        'revision_id': revisionId,
        'product_id': entry.key,
        'product_name': byId[entry.key]!.name,
        'quantity': entry.value,
        'unit_price': byId[entry.key]!.price,
      });
    }
  }
}

class _InvoiceCalculation {
  final double subtotal;
  final double discount;
  final double total;

  const _InvoiceCalculation({
    required this.subtotal,
    required this.discount,
    required this.total,
  });
}
