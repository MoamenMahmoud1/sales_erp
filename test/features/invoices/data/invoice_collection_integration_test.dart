import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sales_erp/features/invoices/data/database/invoice_database.dart';
import 'package:sales_erp/features/invoices/data/repositories/invoice_repository_impl.dart';
import 'package:sales_erp/features/invoices/domain/entities/money.dart';
import 'package:sales_erp/features/invoices/domain/entities/payment.dart';
import 'package:sales_erp/features/invoices/domain/services/invoice_calculator.dart';
import 'package:sales_erp/features/invoices/domain/services/payment_allocation_service.dart';
import 'package:sales_erp/features/invoices/domain/usecases/process_collection.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late InvoiceDatabase database;
  late InvoiceRepositoryImpl repository;
  late ProcessCollection processCollection;

  setUp(() async {
    database = InvoiceDatabase(
      databaseName: 'sales_erp_collection_test.db',
    );

    repository = InvoiceRepositoryImpl(
      database: database,
    );

    processCollection = ProcessCollection(
      repository: repository,
      allocationService: const PaymentAllocationService(
        calculator: InvoiceCalculator(),
      ),
    );

    final db = await database.database;

    final customerId = await db.insert(
      'customers',
      {
        'name': 'Test Customer',
      },
    );

    final invoiceId = await db.insert(
      'invoices',
      {
        'customer_id': customerId,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'updated_at': DateTime(2026, 1, 1).toIso8601String(),
        'paid_at': null,
      },
    );

    await db.insert(
      'invoice_items',
      {
        'invoice_id': invoiceId,
        'product_id': 1,
        'product_name': 'Test Product',
        'unit_price': 1000,
        'quantity': 1,
      },
    );

    await db.insert(
      'payments',
      {
        'invoice_id': invoiceId,
        'cash_amount': 0,
        'transfer_amount': 0,
      },
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'collection persists transaction, allocation, and invoice payment',
    () async {
      final result = await processCollection(
        customerId: 1,
        payment: const Payment(
          cashAmount: Money(300),
          transferAmount: Money(200),
        ),
      );

      // --------------------------------------------------
      // Collection result
      // --------------------------------------------------

      expect(result.isSuccess, isTrue);

      expect(
        result.totalReceived,
        const Money(500),
      );

      expect(
        result.totalOutstanding,
        const Money(1000),
      );

      expect(
        result.allocations,
        hasLength(1),
      );

      final allocation = result.allocations.single;

      expect(
        allocation.invoiceId,
        1,
      );

      expect(
        allocation.cashAmount,
        const Money(300),
      );

      expect(
        allocation.transferAmount,
        const Money(200),
      );

      // --------------------------------------------------
      // Updated invoice
      // --------------------------------------------------

      final updatedInvoice =
          result.updatedInvoices.single;

      expect(
        updatedInvoice.payment.cashAmount,
        const Money(300),
      );

      expect(
        updatedInvoice.payment.transferAmount,
        const Money(200),
      );

      expect(
        updatedInvoice.paidAt,
        isNull,
      );

      // --------------------------------------------------
      // Read SQLite directly
      // --------------------------------------------------

      final db = await database.database;

      // --------------------------------------------------
      // Payment transaction
      // --------------------------------------------------

      final transactionRows = await db.query(
        'payment_transactions',
      );

      expect(
        transactionRows,
        hasLength(1),
      );

      final transaction = transactionRows.single;

      expect(
        transaction['customer_id'],
        1,
      );

      expect(
        transaction['cash_amount'],
        300,
      );

      expect(
        transaction['transfer_amount'],
        200,
      );

      // --------------------------------------------------
      // Payment allocation
      // --------------------------------------------------

      final allocationRows = await db.query(
        'payment_allocations',
      );

      expect(
        allocationRows,
        hasLength(1),
      );

      final allocationRow = allocationRows.single;

      expect(
        allocationRow['payment_transaction_id'],
        transaction['id'],
      );

      expect(
        allocationRow['invoice_id'],
        1,
      );

      expect(
        allocationRow['cash_amount'],
        300,
      );

      expect(
        allocationRow['transfer_amount'],
        200,
      );

      // --------------------------------------------------
      // Current invoice payment
      // --------------------------------------------------

      final paymentRows = await db.query(
        'payments',
        where: 'invoice_id = ?',
        whereArgs: [1],
      );

      expect(
        paymentRows,
        hasLength(1),
      );

      final payment = paymentRows.single;

      expect(
        payment['cash_amount'],
        300,
      );

      expect(
        payment['transfer_amount'],
        200,
      );

      // --------------------------------------------------
      // Invoice
      // --------------------------------------------------

      final invoiceRows = await db.query(
        'invoices',
        where: 'id = ?',
        whereArgs: [1],
      );

      expect(
        invoiceRows,
        hasLength(1),
      );

      final invoice = invoiceRows.single;

      expect(
        invoice['customer_id'],
        1,
      );

      expect(
        invoice['paid_at'],
        isNull,
      );
    },
  );
}