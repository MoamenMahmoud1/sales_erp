import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../../customers/domain/payment_method.dart';
import '../../payment/domain/payment_status.dart';
import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../domain/customer_financial_summary.dart';
import '../domain/daily_sales_summary.dart';
import '../domain/invoice.dart';
import '../domain/invoice_change.dart';
import '../domain/payment_record.dart';
import '../domain/sale_repository.dart';

class LocalSaleRepository
    implements SaleRepository {
  final LocalProductRepository
      _productRepository =
      LocalProductRepository();

  Future<Database> get _database {
    return AppDatabase.database;
  }

  @override
  Future<int> createInvoice({
    required int customerId,
    required Map<int, int> products,
    required PaymentMethod paymentMethod,
    double couponDiscount = 0,
  }) async {
    if (customerId <= 0) {
      throw ArgumentError(
        'Invalid customer ID.',
      );
    }

    if (products.isEmpty) {
      throw ArgumentError(
        'Invoice must contain at least one product.',
      );
    }

    for (final entry in products.entries) {
      if (entry.value <= 0) {
        throw ArgumentError(
          'Product quantity must be greater than zero.',
        );
      }
    }

    if (couponDiscount < 0) {
      throw ArgumentError(
        'Coupon discount cannot be negative.',
      );
    }

    final database = await _database;

    final customerRows =
        await database.query(
      'customers',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (customerRows.isEmpty) {
      throw StateError(
        'Customer $customerId was not found.',
      );
    }

    final availableProducts =
        await _productRepository.getProducts();

    final productMap =
        <int, Product>{
      for (final product
          in availableProducts)
        product.id: product,
    };

    double subtotal = 0;

    for (final entry
        in products.entries) {
      final product =
          productMap[entry.key];

      if (product == null) {
        throw StateError(
          'Product with id ${entry.key} was not found.',
        );
      }

      subtotal +=
          product.price * entry.value;
    }

    final safeDiscount =
        couponDiscount > subtotal
            ? subtotal
            : couponDiscount;

    final total =
        subtotal - safeDiscount;

    return database.transaction<int>(
      (transaction) async {
        final now = DateTime.now()
            .toUtc()
            .toIso8601String();

        final invoiceId =
            await transaction.insert(
          'invoices',
          {
            'customer_id': customerId,
            'created_at': now,
            'updated_at': now,
            'subtotal': subtotal,
            'coupon_discount':
                safeDiscount,
            'total': total,
          },
        );

        for (final entry
            in products.entries) {
          final product =
              productMap[entry.key]!;

          await transaction.insert(
            'invoice_items',
            {
              'invoice_id': invoiceId,
              'product_id': product.id,
              'quantity': entry.value,
              'unit_price':
                  product.price,
            },
          );
        }

        if (total > 0) {
          final status =
              paymentMethod ==
                      PaymentMethod.cash
                  ? PaymentStatus.paid
                  : PaymentStatus.pending;

          await transaction.insert(
            'payments',
            {
              'customer_id':
                  customerId,
              'invoice_id':
                  invoiceId,
              'amount': total,
              'method':
                  paymentMethod.value,
              'status':
                  status.value,
              'reference': null,
              'created_at': now,
              'confirmed_at':
                  status ==
                          PaymentStatus.paid
                      ? now
                      : null,
            },
          );
        }

        return invoiceId;
      },
    );
  }

  @override
  Future<List<Map<String, Object?>>>
      getInvoices() async {
    final database = await _database;

    return database.rawQuery(
      '''
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

        COALESCE(
          (
            SELECT p.method
            FROM payments p
            WHERE p.invoice_id = i.id
            ORDER BY p.id DESC
            LIMIT 1
          ),
          'cash'
        ) AS payment_method,

        COALESCE(
          (
            SELECT p.status
            FROM payments p
            WHERE p.invoice_id = i.id
            ORDER BY p.id DESC
            LIMIT 1
          ),
          'paid'
        ) AS payment_status

      FROM invoices i
      INNER JOIN customers c
        ON c.id = i.customer_id

      ORDER BY i.created_at DESC
      ''',
    );
  }

  @override
  Future<List<Map<String, Object?>>>
      getCustomerInvoices(
    int customerId,
  ) async {
    final database = await _database;

    return database.rawQuery(
      '''
      SELECT
        i.id,
        i.customer_id,
        c.name AS customer_name,
        i.created_at,
        i.updated_at,
        i.subtotal,
        i.coupon_discount,
        i.total,

        COALESCE(
          (
            SELECT p.method
            FROM payments p
            WHERE p.invoice_id = i.id
            ORDER BY p.id DESC
            LIMIT 1
          ),
          'cash'
        ) AS payment_method,

        COALESCE(
          (
            SELECT p.status
            FROM payments p
            WHERE p.invoice_id = i.id
            ORDER BY p.id DESC
            LIMIT 1
          ),
          'paid'
        ) AS payment_status

      FROM invoices i
      INNER JOIN customers c
        ON c.id = i.customer_id

      WHERE i.customer_id = ?

      ORDER BY i.created_at DESC
      ''',
      [customerId],
    );
  }

  @override
  Future<Invoice?> getInvoice(
    int invoiceId,
  ) async {
    final database = await _database;

    final rows =
        await database.rawQuery(
      '''
      SELECT
        i.id,
        i.customer_id,
        i.created_at,
        i.updated_at,
        i.subtotal,
        i.coupon_discount,
        i.total,

        COALESCE(
          (
            SELECT p.method
            FROM payments p
            WHERE p.invoice_id = i.id
            ORDER BY p.id DESC
            LIMIT 1
          ),
          'cash'
        ) AS payment_method,

        COALESCE(
          (
            SELECT p.status
            FROM payments p
            WHERE p.invoice_id = i.id
            ORDER BY p.id DESC
            LIMIT 1
          ),
          'paid'
        ) AS payment_status

      FROM invoices i

      WHERE i.id = ?

      LIMIT 1
      ''',
      [invoiceId],
    );

    if (rows.isEmpty) {
      return null;
    }

    final invoiceRow =
        rows.first;

    final itemRows =
        await database.query(
      'invoice_items',
      columns: [
        'product_id',
        'quantity',
      ],
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id ASC',
    );

    final products =
        <int, int>{};

    for (final row
        in itemRows) {
      products[
              row['product_id'] as int] =
          row['quantity'] as int;
    }

    return Invoice.fromMap(
      invoiceRow,
      products: products,
    );
  }

  @override
  Future<void> updateInvoice({
    required int invoiceId,
    required Map<int, int> products,
  }) async {
    if (invoiceId <= 0) {
      throw ArgumentError(
        'Invalid invoice ID.',
      );
    }

    if (products.isEmpty) {
      throw ArgumentError(
        'Invoice must contain at least one product.',
      );
    }

    for (final entry
        in products.entries) {
      if (entry.value <= 0) {
        throw ArgumentError(
          'Product quantity must be greater than zero.',
        );
      }
    }

    final availableProducts =
        await _productRepository.getProducts();

    final productMap =
        <int, Product>{
      for (final product
          in availableProducts)
        product.id: product,
    };

    double subtotal = 0;

    for (final entry
        in products.entries) {
      final product =
          productMap[entry.key];

      if (product == null) {
        throw StateError(
          'Product with id ${entry.key} was not found.',
        );
      }

      subtotal +=
          product.price * entry.value;
    }

    final database = await _database;

    await database.transaction(
      (transaction) async {
        final invoiceRows =
            await transaction.query(
          'invoices',
          columns: [
            'id',
            'coupon_discount',
          ],
          where: 'id = ?',
          whereArgs: [invoiceId],
          limit: 1,
        );

        if (invoiceRows.isEmpty) {
          throw StateError(
            'Invoice $invoiceId was not found.',
          );
        }

        final existingRows =
            await transaction.query(
          'invoice_items',
          columns: [
            'product_id',
            'quantity',
          ],
          where: 'invoice_id = ?',
          whereArgs: [invoiceId],
        );

        final oldQuantities =
            <int, int>{
          for (final row
              in existingRows)
            row['product_id'] as int:
                row['quantity'] as int,
        };

        final now = DateTime.now()
            .toUtc()
            .toIso8601String();

        for (final entry
            in products.entries) {
          final oldQuantity =
              oldQuantities[
                      entry.key] ??
                  0;

          if (oldQuantity !=
              entry.value) {
            final changedAt =
                DateTime.now().toUtc();

            final expiresAt =
                changedAt.add(
              const Duration(
                days: 7,
              ),
            );

            await transaction.insert(
              'invoice_changes',
              {
                'invoice_id':
                    invoiceId,
                'product_id':
                    entry.key,
                'old_quantity':
                    oldQuantity,
                'new_quantity':
                    entry.value,
                'changed_at':
                    changedAt
                        .toIso8601String(),
                'expires_at':
                    expiresAt
                        .toIso8601String(),
              },
            );
          }
        }

        for (final entry
            in oldQuantities.entries) {
          if (!products
              .containsKey(
            entry.key,
          )) {
            final changedAt =
                DateTime.now().toUtc();

            final expiresAt =
                changedAt.add(
              const Duration(
                days: 7,
              ),
            );

            await transaction.insert(
              'invoice_changes',
              {
                'invoice_id':
                    invoiceId,
                'product_id':
                    entry.key,
                'old_quantity':
                    entry.value,
                'new_quantity': 0,
                'changed_at':
                    changedAt
                        .toIso8601String(),
                'expires_at':
                    expiresAt
                        .toIso8601String(),
              },
            );
          }
        }

        await transaction.delete(
          'invoice_items',
          where:
              'invoice_id = ?',
          whereArgs: [
            invoiceId,
          ],
        );

        for (final entry
            in products.entries) {
          final product =
              productMap[entry.key]!;

          await transaction.insert(
            'invoice_items',
            {
              'invoice_id':
                  invoiceId,
              'product_id':
                  product.id,
              'quantity':
                  entry.value,
              'unit_price':
                  product.price,
            },
          );
        }

        final existingDiscount =
            (invoiceRows.first[
                        'coupon_discount']
                    as num?)
                ?.toDouble() ??
                0;

        final safeDiscount =
            existingDiscount >
                    subtotal
                ? subtotal
                : existingDiscount;

        final total =
            subtotal - safeDiscount;

        await transaction.update(
          'invoices',
          {
            'updated_at': now,
            'subtotal': subtotal,
            'coupon_discount':
                safeDiscount,
            'total': total,
          },
          where: 'id = ?',
          whereArgs: [
            invoiceId,
          ],
        );
      },
    );
  }

  @override
  Future<void> deleteInvoice(
    int invoiceId,
  ) async {
    final database = await _database;

    await database.transaction(
      (transaction) async {
        await transaction.delete(
          'payments',
          where:
              'invoice_id = ?',
          whereArgs: [
            invoiceId,
          ],
        );

        await transaction.delete(
          'invoice_coupons',
          where:
              'invoice_id = ?',
          whereArgs: [
            invoiceId,
          ],
        );

        await transaction.delete(
          'invoice_changes',
          where:
              'invoice_id = ?',
          whereArgs: [
            invoiceId,
          ],
        );

        await transaction.delete(
          'invoice_items',
          where:
              'invoice_id = ?',
          whereArgs: [
            invoiceId,
          ],
        );

        final deleted =
            await transaction.delete(
          'invoices',
          where: 'id = ?',
          whereArgs: [
            invoiceId,
          ],
        );

        if (deleted == 0) {
          throw StateError(
            'Invoice $invoiceId was not found.',
          );
        }
      },
    );
  }

  @override
  Future<List<InvoiceChange>>
      getRecentInvoiceChanges(
    int invoiceId,
  ) async {
    final database = await _database;

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    final rows =
        await database.query(
      'invoice_changes',
      where: '''
        invoice_id = ?
        AND expires_at > ?
      ''',
      whereArgs: [
        invoiceId,
        now,
      ],
      orderBy:
          'changed_at DESC',
    );

    return rows.map(
      (row) {
        return InvoiceChange(
          productId:
              row['product_id'] as int,
          oldQuantity:
              row['old_quantity']
                  as int,
          newQuantity:
              row['new_quantity']
                  as int,
        );
      },
    ).toList(growable: false);
  }

  @override
  Future<List<PaymentRecord>>
      getPendingTransfers() async {
    final database = await _database;

    final rows =
        await database.query(
      'payments',
      where: '''
        method = ?
        AND status = ?
      ''',
      whereArgs: [
        PaymentMethod
            .transfer.value,
        PaymentStatus
            .pending.value,
      ],
      orderBy:
          'created_at ASC',
    );

    return rows.map(
      (row) {
        return PaymentRecord(
          id: row['id'] as int,
          invoiceId:
              row['invoice_id'] as int,
          customerId:
              row['customer_id'] as int,
          amount:
              (row['amount'] as num)
                  .toDouble(),
          paymentMethod:
              paymentMethodFromValue(
            row['method'] as String?,
          ),
          createdAt:
              DateTime.parse(
            row['created_at']
                as String,
          ),
        );
      },
    ).toList(growable: false);
  }

  @override
  Future<void> confirmTransfer(
    int paymentId,
  ) async {
    final database = await _database;

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    final updated =
        await database.update(
      'payments',
      {
        'status':
            PaymentStatus
                .paid.value,
        'confirmed_at': now,
      },
      where: '''
        id = ?
        AND method = ?
        AND status = ?
      ''',
      whereArgs: [
        paymentId,
        PaymentMethod
            .transfer.value,
        PaymentStatus
            .pending.value,
      ],
    );

    if (updated == 0) {
      throw StateError(
        'Payment is not a pending transfer.',
      );
    }
  }

  @override
  Future<CustomerFinancialSummary>
      getCustomerFinancialSummary(
    int customerId,
  ) async {
    final database = await _database;

    final invoiceResult =
        await database.rawQuery(
      '''
      SELECT
        COALESCE(
          SUM(subtotal),
          0
        ) AS subtotal,

        COALESCE(
          SUM(coupon_discount),
          0
        ) AS coupon_discount,

        COALESCE(
          SUM(total),
          0
        ) AS total

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
              WHEN status = ?
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS paid,

        COALESCE(
          SUM(
            CASE
              WHEN method = ?
              AND status = ?
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS pending_transfers

      FROM payments

      WHERE customer_id = ?
      ''',
      [
        PaymentStatus
            .paid.value,
        PaymentMethod
            .transfer.value,
        PaymentStatus
            .pending.value,
        customerId,
      ],
    );

    final invoiceData =
        invoiceResult.first;

    final paymentData =
        paymentResult.first;

    final subtotal =
        (invoiceData[
                    'subtotal']
                as num)
            .toDouble();

    final couponDiscount =
        (invoiceData[
                    'coupon_discount']
                as num)
            .toDouble();

    final total =
        (invoiceData['total']
                as num)
            .toDouble();

    final paid =
        (paymentData['paid']
                as num)
            .toDouble();

    final pendingTransfers =
        (paymentData[
                    'pending_transfers']
                as num)
            .toDouble();

    final balance =
        total -
        paid -
        pendingTransfers;

    return CustomerFinancialSummary(
      subtotal: subtotal,
      couponDiscount:
          couponDiscount,
      total: total,
      paid: paid,
      pendingTransfers:
          pendingTransfers,
      balance:
          balance > 0
              ? balance
              : 0,
    );
  }

  @override
  Future<DailySalesSummary>
      getDailySalesSummary(
    DateTime date,
  ) async {
    final database = await _database;

    final localStart = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final localEnd =
        localStart.add(
      const Duration(days: 1),
    );

    final startUtc =
        localStart
            .toUtc()
            .toIso8601String();

    final endUtc =
        localEnd
            .toUtc()
            .toIso8601String();

    final invoiceResult =
        await database.rawQuery(
      '''
      SELECT
        COUNT(*) AS invoice_count,

        COALESCE(
          SUM(subtotal),
          0
        ) AS subtotal,

        COALESCE(
          SUM(coupon_discount),
          0
        ) AS coupon_discount,

        COALESCE(
          SUM(total),
          0
        ) AS total

      FROM invoices

      WHERE created_at >= ?
        AND created_at < ?
      ''',
      [
        startUtc,
        endUtc,
      ],
    );

    final customerResult =
        await database.rawQuery(
      '''
      SELECT
        COUNT(
          DISTINCT customer_id
        ) AS customer_count

      FROM invoices

      WHERE created_at >= ?
        AND created_at < ?
      ''',
      [
        startUtc,
        endUtc,
      ],
    );

    final paymentResult =
        await database.rawQuery(
      '''
      SELECT

        COALESCE(
          SUM(
            CASE
              WHEN method = ?
              AND status = ?
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS cash_collected,

        COALESCE(
          SUM(
            CASE
              WHEN method = ?
              AND status = ?
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS transfer_collected,

        COALESCE(
          SUM(
            CASE
              WHEN method = ?
              AND status = ?
              THEN amount
              ELSE 0
            END
          ),
          0
        ) AS pending_transfers

      FROM payments

      WHERE created_at >= ?
        AND created_at < ?
      ''',
      [
        PaymentMethod.cash.value,
        PaymentStatus.paid.value,
        PaymentMethod.transfer.value,
        PaymentStatus.paid.value,
        PaymentMethod.transfer.value,
        PaymentStatus.pending.value,
        startUtc,
        endUtc,
      ],
    );

    final invoiceData =
        invoiceResult.first;

    final customerData =
        customerResult.first;

    final paymentData =
        paymentResult.first;

    final invoiceCount =
        (invoiceData[
                    'invoice_count']
                as num)
            .toInt();

    final customerCount =
        (customerData[
                    'customer_count']
                as num)
            .toInt();

    final subtotal =
        (invoiceData['subtotal']
                as num)
            .toDouble();

    final couponDiscount =
        (invoiceData[
                    'coupon_discount']
                as num)
            .toDouble();

    final total =
        (invoiceData['total']
                as num)
            .toDouble();

    final cashCollected =
        (paymentData[
                    'cash_collected']
                as num)
            .toDouble();

    final transferCollected =
        (paymentData[
                    'transfer_collected']
                as num)
            .toDouble();

    final pendingTransfers =
        (paymentData[
                    'pending_transfers']
                as num)
            .toDouble();

    final collected =
        cashCollected +
        transferCollected;

    final outstanding =
        total -
        collected -
        pendingTransfers;

    return DailySalesSummary(
      date: localStart,
      invoiceCount:
          invoiceCount,
      customerCount:
          customerCount,
      subtotal: subtotal,
      couponDiscount:
          couponDiscount,
      total: total,
      cashCollected:
          cashCollected,
      transferCollected:
          transferCollected,
      pendingTransfers:
          pendingTransfers,
      collected: collected,
      outstanding:
          outstanding > 0
              ? outstanding
              : 0,
    );
  }
}

