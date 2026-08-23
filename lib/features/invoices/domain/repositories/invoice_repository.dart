import '../entities/invoice.dart';
import '../entities/payment_transaction.dart';
import '../results/collection_allocation.dart';

abstract interface class InvoiceRepository {
  Future<List<Invoice>> getCustomerInvoices(
    int customerId,
  );

  Future<void> updateInvoices(
    List<Invoice> invoices,
  );

  Future<void> saveCollection({
    required PaymentTransaction transaction,
    required List<CollectionAllocation> allocations,
    required List<Invoice> updatedInvoices,
  });
}