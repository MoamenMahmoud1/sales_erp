import '../../../core/storage/app_database.dart';

import '../../customers/domain/payment_method.dart';

import '../domain/customer_financial_summary.dart';
import '../domain/daily_sales_summary.dart';
import '../domain/invoice.dart';
import '../domain/invoice_change.dart';
import '../domain/payment_record.dart';
import '../domain/sale_repository.dart';

class LocalSaleRepository implements SaleRepository {
  @override
  Future<int> createInvoice({
    required int customerId,
    required Map<int, int> products,
    required PaymentMethod paymentMethod,
    double couponDiscount = 0,
  }) async {
    if (products.isEmpty) {
      throw ArgumentError(
        'Invoice must contain at least one product.',
      );
    }

    if (couponDiscount < 0) {
      throw ArgumentError(
        'Coupon discount cannot be negative.',
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
          'coupon_discount': couponDiscount,
          'total': 0,
        },
      );

      double subtotal = 0;

      for (final entry in products.entries) {
        final productId = entry.key;
        final quantity = entry.value;

        if (quantity <= 0) {
          continue;
        }

        final productRows = await txn.query(
          'products',
          columns: ['id', 'price'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (productRows.isEmpty) {
          throw StateError(
            'Product $productId was not found.',
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
            'product_id': productId,
            'quantity': quantity,
            'unit_price': unitPrice,
          },
        );
      }

      if (subtotal <= 0) {
        throw ArgumentError(
          'Invoice must contain valid products.',
        );
      }

      final safeDiscount =
          couponDiscount > subtotal
              ? subtotal
              : couponDiscount;

      final total = subtotal - safeDiscount;

      await txn.update(
        'invoices',
        {
          'subtotal': subtotal,
          'coupon_discount': safeDiscount,
          'total': total,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      /*
       * Payment is created together with the invoice.
       *
       * Cash:
       *   paid immediately.
       *
       * Transfer:
       *   pending until confirmed.
       */
      await txn.insert(
        'payments',
        {
          'customer_id': customerId,
          'invoice_id': invoiceId,
          'amount': total,
          'method': paymentMethod.value,
          'status':
              paymentMethod == PaymentMethod.cash
                  ? 'paid'
                  : 'pending',
          'reference': null,
          'created_at': now,
          'confirmed_at':
              paymentMethod == PaymentMethod.cash
                  ? now
                  : null,
        },
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
    if (products.isEmpty) {
      throw ArgumentError(
        'Invoice must contain at least one product.',
      );
    }

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
        final productId = entry.key;
        final quantity = entry.value;

        if (quantity <= 0) {
          continue;
        }

        final productRows = await txn.query(
          'products',
          columns: ['id', 'price'],
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );

        if (productRows.isEmpty) {
          throw StateError(
            'Product $productId was not found.',
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
            'product_id': productId,
            'quantity': quantity,
            'unit_price': unitPrice,
          },
        );
      }

      if (subtotal <= 0) {
        throw ArgumentError(
          'Invoice must contain valid products.',
        );
      }

      final currentCouponDiscount =
          (invoiceRows.first['coupon_discount']
                  as num?)
              ?.toDouble() ??
          0;

      final safeDiscount =
          currentCouponDiscount > subtotal
              ? subtotal
              : currentCouponDiscount;

      final total = subtotal - safeDiscount;

      await txn.update(
        'invoices',
        {
          'updated_at': changedAt,
          'subtotal': subtotal,
          'coupon_discount': safeDiscount,
          'total': total,
        },
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      /*
       * IMPORTANT:
       * Editing an invoice does not automatically
       * recreate payments.
       *
       * Existing payments stay attached to the
       * invoice.
       */
    });
  }

  @override
  Future<void> deleteInvoice(
    int invoiceId,
  ) async {
    final database = await AppDatabase.database;

    await database.transaction((txn) async {
      await txn.delete(
        'payments',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

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
  Future<List<PaymentRecord>>
      getPendingTransfers() async {
    final database = await AppDatabase.database;

    final rows = await database.query(
      'payments',
      where: '''
        method = ?
        AND status = ?
      ''',
      whereArgs: [
        PaymentMethod.transfer.value,
        'pending',
      ],
      orderBy: 'created_at ASC',
    );

    return rows.map((row) {
      return PaymentRecord(
        id: row['id'] as int,
        invoiceId:
            row['invoice_id'] as int,
        customerId:
            row['customer_id'] as int,
        amount:
            (row['amount'] as num).toDouble(),
        paymentMethod:
            PaymentMethodExtension.fromValue(
          row['method'] as String? ?? 'transfer',
        ),
        createdAt:
            DateTime.parse(
          row['created_at'] as String,
        ),
      );
    }).toList();
  }

  @override
  Future<void> confirmTransfer(
    int invoiceId,
  ) async {
    final database = await AppDatabase.database;

    final now =
        DateTime.now().toUtc().toIso8601String();

    await database.update(
      'payments',
      {
        'status': 'paid',
        'confirmed_at': now,
      },
      where: '''
        invoice_id = ?
        AND method = ?
        AND status = ?
      ''',
      whereArgs: [
        invoiceId,
        PaymentMethod.transfer.value,
        'pending',
      ],
    );
  }

  @override
  Future<CustomerFinancialSummary>
      getCustomerFinancialSummary(
    int customerId,
  ) async {
    final database = await AppDatabase.database;

    final invoiceResult =
        await database.rawQuery(
      '''
      SELECT
        COALESCE(SUM(subtotal), 0) AS subtotal,
        COALESCE(SUM(coupon_discount), 0)
          AS coupon_discount,
        COALESCE(SUM(total), 0) AS total
      FROM invoices
      WHERE customer_id = ?
      ''',
      [customerId],
    );

    final paymentResult =
        await database.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(
            CASE
              WHEN status = 'paid'
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS paid,

        COALESCE(
          SUM(
            CASE
              WHEN method = 'transfer'
               AND status = 'pending'
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS pending
      FROM payments
      WHERE customer_id = ?
      ''',
      [customerId],
    );

    final subtotal =
        (invoiceResult.first['subtotal'] as num)
            .toDouble();

    final couponDiscount =
        (invoiceResult.first['coupon_discount']
                as num)
            .toDouble();

    final total =
        (invoiceResult.first['total'] as num)
            .toDouble();

    final paid =
        (paymentResult.first['paid'] as num)
            .toDouble();

    final pending =
        (paymentResult.first['pending'] as num)
            .toDouble();

    final balance =
        total - paid - pending;

    return CustomerFinancialSummary(
      subtotal: subtotal,
      couponDiscount: couponDiscount,
      total: total,
      paid: paid,
      pendingTransfers: pending,
      balance: balance > 0 ? balance : 0,
    );
  }

  @override
  Future<DailySalesSummary>
      getDailySalesSummary(
    DateTime date,
  ) async {
    final database = await AppDatabase.database;

    /*
     * We use UTC day boundaries because all records
     * are stored in UTC.
     */

    final start = DateTime.utc(
      date.year,
      date.month,
      date.day,
    );

    final end = start.add(
      const Duration(days: 1),
    );

    final startString =
        start.toIso8601String();

    final endString =
        end.toIso8601String();

    final invoiceResult =
        await database.rawQuery(
      '''
      SELECT
        COUNT(*) AS invoice_count,
        COUNT(DISTINCT customer_id)
          AS customer_count,
        COALESCE(SUM(subtotal), 0)
          AS subtotal,
        COALESCE(SUM(coupon_discount), 0)
          AS coupon_discount,
        COALESCE(SUM(total), 0)
          AS total
      FROM invoices
      WHERE created_at >= ?
        AND created_at < ?
      ''',
      [
        startString,
        endString,
      ],
    );

    final paymentResult =
        await database.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(
            CASE
              WHEN method = 'cash'
               AND status = 'paid'
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS cash,

        COALESCE(
          SUM(
            CASE
              WHEN method = 'transfer'
               AND status = 'paid'
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS transfer,

        COALESCE(
          SUM(
            CASE
              WHEN method = 'transfer'
               AND status = 'pending'
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS pending
      FROM payments
      WHERE created_at >= ?
        AND created_at < ?
      ''',
      [
        startString,
        endString,
      ],
    );

    final invoiceRow =
        invoiceResult.first;

    final paymentRow =
        paymentResult.first;

    final invoiceCount =
        (invoiceRow['invoice_count'] as num)
            .toInt();

    final customerCount =
        (invoiceRow['customer_count'] as num)
            .toInt();

    final subtotal =
        (invoiceRow['subtotal'] as num)
            .toDouble();

    final couponDiscount =
        (invoiceRow['coupon_discount'] as num)
            .toDouble();

    final total =
        (invoiceRow['total'] as num)
            .toDouble();

    final cashCollected =
        (paymentRow['cash'] as num)
            .toDouble();

    final transferCollected =
        (paymentRow['transfer'] as num)
            .toDouble();

    final pendingTransfers =
        (paymentRow['pending'] as num)
            .toDouble();

    final collected =
        cashCollected + transferCollected;

    final outstanding =
        total - collected - pendingTransfers;

    return DailySalesSummary(
      date: date,
      invoiceCount: invoiceCount,
      customerCount: customerCount,
      subtotal: subtotal,
      couponDiscount: couponDiscount,
      total: total,
      cashCollected: cashCollected,
      transferCollected: transferCollected,
      pendingTransfers: pendingTransfers,
      collected: collected,
      outstanding:
          outstanding > 0 ? outstanding : 0,
    );
  }
}