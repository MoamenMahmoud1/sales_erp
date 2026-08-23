
import '../entities/payment.dart';
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

    final invoices =
        await repository.getCustomerInvoices(
      customerId,
    );

    // --------------------------------------------------
    // 2. Allocate payment
    // --------------------------------------------------

    final result =
        allocationService.allocate(
      invoices: invoices,
      payment: payment,
      now: DateTime.now(),
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
    // 4. Save updated invoices
    // --------------------------------------------------

    await repository.updateInvoices(
      result.updatedInvoices,
    );

    // --------------------------------------------------
    // 5. Return result
    // --------------------------------------------------

    return result;
  }
}
