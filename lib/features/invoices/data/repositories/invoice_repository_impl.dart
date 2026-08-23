import 'package:sqflite/sqflite.dart';

import '../../domain/entities/invoice.dart';
import '../../domain/entities/payment_transaction.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/results/collection_allocation.dart';
import '../database/invoice_database.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/payment_allocation_model.dart';
import '../models/payment_model.dart';
import '../models/payment_transaction_model.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final InvoiceDatabase database;

  const InvoiceRepositoryImpl({
    required this.database,
  });

  @override
  Future<List<Invoice>> getCustomerInvoices(
    int customerId,
  ) async {
    final db = await database.database;

    final invoiceRows = await db.query(
      'invoices',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at ASC',
    );

    final invoices = <Invoice>[];

    for (final invoiceRow in invoiceRows) {
      final invoiceId = invoiceRow['id'] as int;

      final itemRows = await db.query(
        'invoice_items',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
      );

      final paymentRows = await db.query(
        'payments',
        where: 'invoice_id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );

      final items = itemRows
          .map(
            InvoiceItemModel.fromMap,
          )
          .toList();

      final payment = paymentRows.isEmpty
          ? PaymentModel(
              id: 0,
              invoiceId: invoiceId,
              cashAmount: 0,
              transferAmount: 0,
            )
          : PaymentModel.fromMap(
              paymentRows.first,
            );

      final model = InvoiceModel.fromMap(
        invoiceRow,
        items: items,
        payment: payment,
      );

      invoices.add(
        model.toEntity(),
      );
    }

    return List<Invoice>.unmodifiable(
      invoices,
    );
  }

  @override
  Future<void> updateInvoices(
    List<Invoice> invoices,
  ) async {
    final db = await database.database;

    await db.transaction(
      (transaction) async {
        for (final invoice in invoices) {
          await _updateInvoice(
            transaction,
            invoice,
          );
        }
      },
    );
  }

  @override
  Future<void> saveCollection({
    required PaymentTransaction transaction,
    required List<CollectionAllocation> allocations,
    required List<Invoice> updatedInvoices,
  }) async {
    final db = await database.database;

    await db.transaction(
      (transactionDb) async {
        // --------------------------------------------------
        // 1. Create payment transaction
        // --------------------------------------------------

        final transactionModel =
            PaymentTransactionModel.fromEntity(
          transaction,
        );

        final transactionId =
            await transactionDb.insert(
          'payment_transactions',
          transactionModel.toMap(),
        );

        // --------------------------------------------------
        // 2. Save allocations
        // --------------------------------------------------

        for (final allocation in allocations) {
          final allocationModel =
              PaymentAllocationModel(
            paymentTransactionId: transactionId,
            invoiceId: allocation.invoiceId,
            cashAmount:
                allocation.cashAmount.minorUnits,
            transferAmount:
                allocation.transferAmount.minorUnits,
          );

          await transactionDb.insert(
            'payment_allocations',
            allocationModel.toMap(),
          );
        }

        // --------------------------------------------------
        // 3. Update invoices
        // --------------------------------------------------

        for (final invoice in updatedInvoices) {
          await _updateInvoice(
            transactionDb,
            invoice,
          );
        }
      },
    );
  }

  Future<void> _updateInvoice(
    Transaction transaction,
    Invoice invoice,
  ) async {
    final invoiceModel = InvoiceModel.fromEntity(
      invoice,
      items: invoice.items
          .map(
            (item) {
              return InvoiceItemModel.fromEntity(
                invoiceId: invoice.id,
                entity: item,
              );
            },
          )
          .toList(),
      payment: PaymentModel.fromEntity(
        id: 0,
        invoiceId: invoice.id,
        entity: invoice.payment,
      ),
    );

    // --------------------------------------------------
    // Invoice
    // --------------------------------------------------

    await transaction.update(
      'invoices',
      invoiceModel.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );

    // --------------------------------------------------
    // Invoice items
    // --------------------------------------------------

    await transaction.delete(
      'invoice_items',
      where: 'invoice_id = ?',
      whereArgs: [invoice.id],
    );

    for (final item in invoiceModel.items) {
      await transaction.insert(
        'invoice_items',
        item.toMap(),
      );
    }

    // --------------------------------------------------
    // Current invoice payment
    // --------------------------------------------------

    await transaction.delete(
      'payments',
      where: 'invoice_id = ?',
      whereArgs: [invoice.id],
    );

    await transaction.insert(
      'payments',
      invoiceModel.payment.toMap(),
    );
  }
}