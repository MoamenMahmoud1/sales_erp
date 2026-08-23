import '../entities/payment.dart';
import '../entities/payment_transaction.dart';
import '../repositories/invoice_repository.dart';
import '../results/collection_result.dart';
import '../services/payment_allocation_service.dart';

class ProcessCollection {
  final InvoiceRepository repository;
  final PaymentAllocationService allocationService;

  const ProcessCollection({
    required this.repository,
    required this.allocationService,
  });

  Future<CollectionResult> call({
    required int customerId,
    required Payment payment,
  }) async {
    // --------------------------------------------------
    // 1. Get customer's invoices
    // --------------------------------------------------

    final invoices = await repository.getCustomerInvoices(
      customerId,
    );

    // --------------------------------------------------
    // 2. Allocate payment
    // --------------------------------------------------

    final now = DateTime.now();

    final result = allocationService.allocate(
      invoices: invoices,
      payment: payment,
      now: now,
    );

    // --------------------------------------------------
    // 3. Validation failed
    //
    // Don't touch the database.
    // --------------------------------------------------

    if (!result.isSuccess) {
      return result;
    }

    // --------------------------------------------------
    // 4. Nothing was received
    //
    // There is no financial transaction to persist.
    // --------------------------------------------------

    if (result.totalReceived == result.totalOutstanding &&
        result.allocations.isEmpty) {
      return result;
    }

    if (result.allocations.isEmpty) {
      return result;
    }

    // --------------------------------------------------
    // 5. Create payment transaction
    //
    // id = 0 because SQLite generates it.
    // --------------------------------------------------

    final transaction = PaymentTransaction(
      id: 0,
      customerId: customerId,
      cashAmount: payment.cashAmount,
      transferAmount: payment.transferAmount,
      createdAt: now,
    );

    // --------------------------------------------------
    // 6. Persist the complete collection atomically
    // --------------------------------------------------

    await repository.saveCollection(
      transaction: transaction,
      allocations: result.allocations,
      updatedInvoices: result.updatedInvoices,
    );

    // --------------------------------------------------
    // 7. Return result
    // --------------------------------------------------

    return result;
  }
}