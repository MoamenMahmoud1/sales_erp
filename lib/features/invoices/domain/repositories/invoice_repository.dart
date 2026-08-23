import '../entities/invoice.dart';

abstract interface class InvoiceRepository {
  Future<List<Invoice>> getCustomerInvoices(
    int customerId,
  );

  Future<void> updateInvoices(
    List<Invoice> invoices,
  );
}
