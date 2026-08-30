import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../../customers/domain/payment_method.dart';
import '../../products/data/local_product_repository.dart';

class LocalSaleRepository {
  final LocalProductRepository _productRepository =
      LocalProductRepository();

  Future<Database> get _database => AppDatabase.database;

  Future<List<Map<String, Object?>>> getInvoices() async {
    final database = await _database;
    return database.rawQuery('''
      SELECT i.id, i.customer_id, c.name AS customer_name,
             i.created_at, i.updated_at, i.subtotal,
             i.coupon_discount, i.total
      FROM invoices i
      INNER JOIN customers c ON c.id = i.customer_id
      ORDER BY i.created_at DESC
    ''');
  }

  Future<List<Map<String, Object?>>> getCustomerInvoices(
    int customerId,
  ) async {
    final database = await _database;
    return database.rawQuery('''
      SELECT i.id, i.customer_id, c.name AS customer_name,
             i.created_at, i.updated_at, i.subtotal,
             i.coupon_discount, i.total
      FROM invoices i
      INNER JOIN customers c ON c.id = i.customer_id
      WHERE i.customer_id = ?
      ORDER BY i.created_at DESC
    ''', [customerId]);
  }

  /// يجيب رأس الفاتورة كامل (خالص/مستحق/طريقة الدفع/بيانات العميل)
  /// مع عناصرها بأسماء المنتجات، جاهز للعرض أو المشاركة.
  Future<Map<String, Object?>?> getInvoiceWithItems(int invoiceId) async {
    final database = await _database;

    final headers = await database.rawQuery('''
      SELECT i.id, i.customer_id, c.name AS customer_name,
             c.phone AS customer_phone,
             i.created_at, i.updated_at, i.subtotal,
             i.coupon_discount, i.total,
             p.amount AS paid_amount,
             p.method AS payment_method,
             p.status AS payment_status
      FROM invoices i
      INNER JOIN customers c ON c.id = i.customer_id
      LEFT JOIN payments p
        ON p.invoice_id = i.id
        AND p.id = (
          SELECT MIN(id) FROM payments WHERE invoice_id = i.id
        )
      WHERE i.id = ?
    ''', [invoiceId]);

    if (headers.isEmpty) return null;
    final header = headers.first;

    final items = await database.rawQuery('''
      SELECT ii.product_id, pr.name AS product_name,
             ii.quantity, ii.unit_price
      FROM invoice_items ii
      INNER JOIN products pr ON pr.id = ii.product_id
      WHERE ii.invoice_id = ?
      ORDER BY ii.id ASC
    ''', [invoiceId]);

    return {...header, 'items': items};
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
    var subtotal = 0.0;
    for (final entry in products.entries) {
      final product = byId[entry.key];
      if (product == null || entry.value <= 0) {
        throw ArgumentError('Invalid invoice product.');
      }
      subtotal += product.price * entry.value;
    }
    final discount = couponDiscount.clamp(0, subtotal).toDouble();
    final total = subtotal - discount;
    final database = await _database;
    return database.transaction((transaction) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final invoiceId = await transaction.insert('invoices', {
        'customer_id': customerId,
        'created_at': now,
        'updated_at': now,
        'subtotal': subtotal,
        'coupon_discount': discount,
        'total': total,
      });
      for (final entry in products.entries) {
        await transaction.insert('invoice_items', {
          'invoice_id': invoiceId,
          'product_id': entry.key,
          'quantity': entry.value,
          'unit_price': byId[entry.key]!.price,
        });
      }
      await transaction.insert('payments', {
        'customer_id': customerId,
        'invoice_id': invoiceId,
        'amount': 0,
        'method': paymentMethod.value,
        'status': 'pending',
        'created_at': now,
      });
      return invoiceId;
    });
  }

  Future<void> deleteInvoice(int invoiceId) async {
    final database = await _database;
    await database.delete('invoices', where: 'id = ?', whereArgs: [invoiceId]);
  }
}
